package autoship

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

func TestNewValidation(t *testing.T) {
	shipFunc := func(ctx context.Context) (ShipResult, error) {
		return ShipResult{}, nil
	}
	selector := func(results []ShipResult, count int) []ShipResult {
		return results
	}

	_, err := New(Config{MonthlySpendCap: 0, ShipInterval: time.Minute, SurvivorCount: 1}, shipFunc, selector)
	if err == nil {
		t.Error("expected error for zero monthly spend cap")
	}

	_, err = New(Config{MonthlySpendCap: 10, ShipInterval: 0, SurvivorCount: 1}, shipFunc, selector)
	if err == nil {
		t.Error("expected error for zero ship interval")
	}

	_, err = New(Config{MonthlySpendCap: 10, ShipInterval: time.Minute, SurvivorCount: -1}, shipFunc, selector)
	if err == nil {
		t.Error("expected error for negative survivor count")
	}

	_, err = New(Config{MonthlySpendCap: 10, ShipInterval: time.Minute, SurvivorCount: 1}, nil, selector)
	if err == nil {
		t.Error("expected error for nil shipFunc")
	}

	_, err = New(Config{MonthlySpendCap: 10, ShipInterval: time.Minute, SurvivorCount: 1}, shipFunc, nil)
	if err == nil {
		t.Error("expected error for nil selector")
	}
}

func TestAutonomousShipLoop_SpendCapAndSurvivors(t *testing.T) {
	var callCount int32
	shipFunc := func(ctx context.Context) (ShipResult, error) {
		atomic.AddInt32(&callCount, 1)
		return ShipResult{
			ID:        "id",
			Spend:     5,
			Timestamp: time.Now(),
		}, nil
	}
	selector := func(results []ShipResult, count int) []ShipResult {
		if len(results) < count {
			count = len(results)
		}
		return results[:count]
	}

	cfg := Config{
		MonthlySpendCap: 15,
		ShipInterval:    10 * time.Millisecond,
		SurvivorCount:   2,
	}

	loop, err := New(cfg, shipFunc, selector)
	if err != nil {
		t.Fatalf("failed to create loop: %v", err)
	}

	loop.Start()
	defer loop.Stop()

	// Wait enough time for multiple ship attempts
	time.Sleep(100 * time.Millisecond)

	// Check call count: should not exceed 3 because 3*5=15 spend cap
	if c := atomic.LoadInt32(&callCount); c > 3 {
		t.Errorf("shipFunc called %d times, expected at most 3", c)
	}

	survivors := loop.Survivors()
	if len(survivors) > cfg.SurvivorCount {
		t.Errorf("survivors count %d exceeds survivor count %d", len(survivors), cfg.SurvivorCount)
	}

	// Check total spend in survivors does not exceed cap
	var totalSpend float64
	for _, s := range survivors {
		totalSpend += s.Spend
	}
	if totalSpend > cfg.MonthlySpendCap {
		t.Errorf("total spend %f exceeds monthly spend cap %f", totalSpend, cfg.MonthlySpendCap)
	}
}

func TestAutonomousShipLoop_ShipFuncError(t *testing.T) {
	var called int32
	shipFunc := func(ctx context.Context) (ShipResult, error) {
		atomic.AddInt32(&called, 1)
		return ShipResult{}, errors.New("fail")
	}
	selector := func(results []ShipResult, count int) []ShipResult {
		return nil
	}

	cfg := Config{
		MonthlySpendCap: 10,
		ShipInterval:    10 * time.Millisecond,
		SurvivorCount:   1,
	}

	loop, err := New(cfg, shipFunc, selector)
	if err != nil {
		t.Fatalf("failed to create loop: %v", err)
	}

	loop.Start()
	defer loop.Stop()

	time.Sleep(50 * time.Millisecond)

	if c := atomic.LoadInt32(&called); c == 0 {
		t.Error("shipFunc was never called")
	}

	survivors := loop.Survivors()
	if len(survivors) != 0 {
		t.Errorf("expected no survivors, got %d", len(survivors))
	}
}

func TestAutonomousShipLoop_PruningOldHistory(t *testing.T) {
	shipFunc := func(ctx context.Context) (ShipResult, error) {
		return ShipResult{
			ID:        "id",
			Spend:     5,
			Timestamp: time.Now(),
		}, nil
	}
	selector := func(results []ShipResult, count int) []ShipResult {
		return results
	}

	cfg := Config{
		MonthlySpendCap: 100,
		ShipInterval:    time.Hour, // won't auto ship in test
		SurvivorCount:   10,
	}

	loop, err := New(cfg, shipFunc, selector)
	if err != nil {
		t.Fatalf("failed to create loop: %v", err)
	}

	// Manually add old and new ShipResults
	oldTime := time.Now().AddDate(0, 0, -31)
	loop.mu.Lock()
	loop.history = []ShipResult{
		{ID: "old1", Spend: 10, Timestamp: oldTime},
		{ID: "new1", Spend: 20, Timestamp: time.Now()},
	}
	loop.currentSpend = 30
	loop.mu.Unlock()

	// Call pruneHistory via tryShip (which locks)
	loop.tryShip()

	loop.mu.Lock()
	defer loop.mu.Unlock()
	if len(loop.history) != 1 {
		t.Errorf("expected 1 history item after pruning, got %d", len(loop.history))
	}
	if loop.history[0].ID != "new1" {
		t.Errorf("expected remaining history item to be 'new1', got %q", loop.history[0].ID)
	}
	if loop.currentSpend != 20 {
		t.Errorf("expected currentSpend 20 after pruning, got %f", loop.currentSpend)
	}
}
