import fs from 'fs';
import path from 'path';
import { DefaultModelManager } from './defaultModelManager';

const TEST_STORAGE_PATH = path.join(__dirname, '../../tmp/test-models');

function cleanup() {
  if (fs.existsSync(TEST_STORAGE_PATH)) {
    fs.rmSync(TEST_STORAGE_PATH, { recursive: true, force: true });
  }
}

describe('DefaultModelManager', () => {
  beforeEach(() => {
    cleanup();
  });

  afterAll(() => {
    cleanup();
  });

  it('should add and retrieve a model', () => {
    const manager = new DefaultModelManager({
      staleThresholdMs: 1000 * 60 * 60,
      modelStoragePath: TEST_STORAGE_PATH,
    });
    manager.addModel('model1', { foo: 'bar' });
    const model = manager.getModel('model1');
    expect(model).toBeDefined();
    expect(model?.data.foo).toBe('bar');
  });

  it('should detect stale models correctly', () => {
    const manager = new DefaultModelManager({
      staleThresholdMs: 1000,
      modelStoragePath: TEST_STORAGE_PATH,
    });
    manager.addModel('model1', { foo: 'bar' });
    const model = manager.getModel('model1')!;
    // artificially set lastRefreshed to past
    model.lastRefreshed = Date.now() - 2000;
    expect(manager.isStale(model)).toBe(true);
  });

  it('should refresh a stale model and update lastRefreshed', async () => {
    const manager = new DefaultModelManager({
      staleThresholdMs: 1000,
      modelStoragePath: TEST_STORAGE_PATH,
    });
    manager.addModel('model1', { foo: 'bar' });
    const model = manager.getModel('model1')!;
    model.lastRefreshed = Date.now() - 2000;
    // Save stale model state
    manager['saveModel'](model);

    const refreshed = await manager.refreshModel('model1');
    expect(refreshed.lastRefreshed).toBeGreaterThan(model.lastRefreshed);
    expect(refreshed.data.refreshedAt).toBeDefined();
  });

  it('should refresh all stale models', async () => {
    const manager = new DefaultModelManager({
      staleThresholdMs: 1000,
      modelStoragePath: TEST_STORAGE_PATH,
    });
    manager.addModel('model1', { foo: 'bar' });
    manager.addModel('model2', { foo: 'baz' });

    // Make model1 stale
    const model1 = manager.getModel('model1')!;
    model1.lastRefreshed = Date.now() - 2000;
    manager['saveModel'](model1);

    // model2 is fresh
    const model2 = manager.getModel('model2')!;

    const refreshedIds = await manager.refreshStaleModels();
    expect(refreshedIds).toContain('model1');
    expect(refreshedIds).not.toContain('model2');

    const refreshedModel1 = manager.getModel('model1')!;
    expect(refreshedModel1.lastRefreshed).toBeGreaterThan(model1.lastRefreshed);
  });
});
