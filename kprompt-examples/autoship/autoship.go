package autoship

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

// Config holds configuration for the autonomous ship loop.
type Config struct {
	MonthlySpendCap float64       // Maximum allowed spend per month in USD
	ShipInterval    time.Duration // Interval between ship attempts
	SurvivorCount   int           // Number of survivors to keep for next iteration
}

// ShipResult represents the outcome of a ship attempt.
type ShipResult struct {
	ID        string  // Unique identifier of the shipped item
	Spend     float64 // Spend incurred by this ship
	Timestamp time.Time
}

// ShipFunc is the function signature for a ship attempt.
type ShipFunc func(ctx context.Context) (ShipResult, error)

// SurvivorSelector selects survivors from a slice of ShipResults.
type SurvivorSelector func(results []ShipResult, count int) []ShipResult

// AutonomousShipLoop manages autonomous shipping under a monthly spend cap with survivor selection.
type AutonomousShipLoop struct {
	cfg       Config
	shipFunc  ShipFunc
	selector  SurvivorSelector

	mu           sync.Mutex
	history      []ShipResult
	currentSpend float64
	survivors    []ShipResult

	ctx    context.Context
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

// New creates a new AutonomousShipLoop with the given config, ship function, and survivor selector.
func New(cfg Config, shipFunc ShipFunc, selector SurvivorSelector) (*AutonomousShipLoop, error) {
	if cfg.MonthlySpendCap <= 0 {
		return nil, errors.New("monthly spend cap must be positive")
	}
	if cfg.ShipInterval <= 0 {
		return nil, errors.New("ship interval must be positive")
	}
	if cfg.SurvivorCount < 0 {
		return nil, errors.New("survivor count cannot be negative")
	}
	if shipFunc == nil {
		return nil, errors.New("shipFunc cannot be nil")
	}
	if selector == nil {
		return nil, errors.New("selector cannot be nil")
	}

	ctx, cancel := context.WithCancel(context.Background())
	return &AutonomousShipLoop{
		cfg:      cfg,
		shipFunc: shipFunc,
		selector: selector,
		ctx:      ctx,
		cancel:   cancel,
	}, nil
}

// Start begins the autonomous ship loop in a background goroutine.
func (a *AutonomousShipLoop) Start() {
	a.wg.Add(1)
	go a.loop()
}

// Stop cancels the autonomous ship loop and waits for it to finish.
func (a *AutonomousShipLoop) Stop() {
	a.cancel()
	a.wg.Wait()
}

// loop runs the autonomous ship loop until context cancellation.
func (a *AutonomousShipLoop) loop() {
	defer a.wg.Done()
	ticker := time.NewTicker(a.cfg.ShipInterval)
	defer ticker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			return
		case <-ticker.C:
			a.tryShip()
		}
	}
}

// tryShip attempts to ship if under the monthly spend cap.
func (a *AutonomousShipLoop) tryShip() {
	a.mu.Lock()
	defer a.mu.Unlock()

	now := time.Now()
	a.pruneHistory(now)

	if a.currentSpend >= a.cfg.MonthlySpendCap {
		// Spend cap reached, skip shipping
		return
	}

	// Attempt to ship
	result, err := a.shipFunc(a.ctx)
	if err != nil {
		// Log error and skip this round
		fmt.Printf("autoship: ship attempt failed: %v\n", err)
		return
	}

	// Check if adding this spend exceeds cap
	if a.currentSpend+result.Spend > a.cfg.MonthlySpendCap {
		// Skip adding this ship to avoid exceeding cap
		return
	}

	// Add result to history and update spend
	a.history = append(a.history, result)
	a.currentSpend += result.Spend

	// Update survivors
	a.survivors = a.selector(a.history, a.cfg.SurvivorCount)
}

// pruneHistory removes ShipResults older than 30 days and updates currentSpend.
func (a *AutonomousShipLoop) pruneHistory(now time.Time) {
	threshold := now.AddDate(0, 0, -30)
	newHistory := a.history[:0]
	var spend float64
	for _, r := range a.history {
		if r.Timestamp.After(threshold) {
			newHistory = append(newHistory, r)
			spend += r.Spend
		}
	}
	a.history = newHistory
	a.currentSpend = spend
}

// Survivors returns a copy of the current survivors.
func (a *AutonomousShipLoop) Survivors() []ShipResult {
	a.mu.Lock()
	defer a.mu.Unlock()

	cpy := make([]ShipResult, len(a.survivors))
	copy(cpy, a.survivors)
	return cpy
}
