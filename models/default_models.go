package models

import (
	"sync"
	"time"
)

// DefaultModel represents a default model with versioning and timestamp.
type DefaultModel struct {
	Name      string
	Version   string
	UpdatedAt time.Time
	// other fields...
}

// ModelStore holds the default models and their metadata.
type ModelStore struct {
	mu     sync.RWMutex
	models map[string]DefaultModel
}

// NewModelStore creates a new ModelStore with initial models.
func NewModelStore(initialModels []DefaultModel) *ModelStore {
	ms := &ModelStore{
		models: make(map[string]DefaultModel),
	}
	for _, m := range initialModels {
		ms.models[m.Name] = m
	}
	return ms
}

// GetModel returns the model by name.
func (ms *ModelStore) GetModel(name string) (DefaultModel, bool) {
	ms.mu.RLock()
	defer ms.mu.RUnlock()
	m, ok := ms.models[name]
	return m, ok
}

// IsStale checks if the model is stale compared to a given version or timestamp.
func (ms *ModelStore) IsStale(name string, currentVersion string, maxAge time.Duration) bool {
	ms.mu.RLock()
	defer ms.mu.RUnlock()
	m, ok := ms.models[name]
	if !ok {
		// If model does not exist, consider it stale.
		return true
	}
	if m.Version != currentVersion {
		return true
	}
	if time.Since(m.UpdatedAt) > maxAge {
		return true
	}
	return false
}

// RefreshModel updates the model in the store.
func (ms *ModelStore) RefreshModel(newModel DefaultModel) {
	ms.mu.Lock()
	defer ms.mu.Unlock()
	ms.models[newModel.Name] = newModel
}
