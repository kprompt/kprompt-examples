package models

import (
	"testing"
	"time"
)

func TestModelStore_IsStale(t *testing.T) {
	now := time.Now()
	model := DefaultModel{
		Name:      "test-model",
		Version:   "v1.0",
		UpdatedAt: now.Add(-2 * time.Hour),
	}
	store := NewModelStore([]DefaultModel{model})

	tests := []struct {
		name           string
		modelName      string
		currentVersion string
		maxAge         time.Duration
		wantStale      bool
	}{
		{
			name:           "model up to date and fresh",
			modelName:      "test-model",
			currentVersion: "v1.0",
			maxAge:         3 * time.Hour,
			wantStale:      false,
		},
		{
			name:           "model version mismatch",
			modelName:      "test-model",
			currentVersion: "v1.1",
			maxAge:         3 * time.Hour,
			wantStale:      true,
		},
		{
			name:           "model stale by age",
			modelName:      "test-model",
			currentVersion: "v1.0",
			maxAge:         1 * time.Hour,
			wantStale:      true,
		},
		{
			name:           "model missing",
			modelName:      "missing-model",
			currentVersion: "v1.0",
			maxAge:         1 * time.Hour,
			wantStale:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := store.IsStale(tt.modelName, tt.currentVersion, tt.maxAge)
			if got != tt.wantStale {
				t.Errorf("IsStale() = %v, want %v", got, tt.wantStale)
			}
		})
	}
}

func TestModelStore_RefreshModel(t *testing.T) {
	now := time.Now()
	store := NewModelStore([]DefaultModel{})

	newModel := DefaultModel{
		Name:      "new-model",
		Version:   "v1.0",
		UpdatedAt: now,
	}

	store.RefreshModel(newModel)

	got, ok := store.GetModel("new-model")
	if !ok {
		t.Fatalf("expected model to be present after refresh")
	}
	if got.Version != "v1.0" {
		t.Errorf("expected version v1.0, got %s", got.Version)
	}
	if !got.UpdatedAt.Equal(now) {
		t.Errorf("expected UpdatedAt %v, got %v", now, got.UpdatedAt)
	}
}
