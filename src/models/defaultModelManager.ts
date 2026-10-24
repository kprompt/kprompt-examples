import fs from 'fs';
import path from 'path';

export interface DefaultModel {
  id: string;
  data: any;
  lastRefreshed: number; // timestamp in ms
}

export interface DefaultModelManagerOptions {
  staleThresholdMs: number; // e.g. 24 * 60 * 60 * 1000 for 24 hours
  modelStoragePath: string;
}

export class DefaultModelManager {
  private models: Map<string, DefaultModel> = new Map();
  private staleThresholdMs: number;
  private modelStoragePath: string;

  constructor(options: DefaultModelManagerOptions) {
    this.staleThresholdMs = options.staleThresholdMs;
    this.modelStoragePath = options.modelStoragePath;
    this.loadModels();
  }

  private loadModels() {
    if (!fs.existsSync(this.modelStoragePath)) {
      fs.mkdirSync(this.modelStoragePath, { recursive: true });
      return;
    }
    const files = fs.readdirSync(this.modelStoragePath);
    for (const file of files) {
      if (file.endsWith('.json')) {
        try {
          const fullPath = path.join(this.modelStoragePath, file);
          const content = fs.readFileSync(fullPath, 'utf-8');
          const model: DefaultModel = JSON.parse(content);
          if (model.id) {
            this.models.set(model.id, model);
          }
        } catch {
          // ignore corrupted files
        }
      }
    }
  }

  private saveModel(model: DefaultModel) {
    const filePath = path.join(this.modelStoragePath, `${model.id}.json`);
    fs.writeFileSync(filePath, JSON.stringify(model, null, 2), 'utf-8');
  }

  /**
   * Check if a model is stale based on lastRefreshed timestamp.
   */
  isStale(model: DefaultModel): boolean {
    const now = Date.now();
    return now - model.lastRefreshed > this.staleThresholdMs;
  }

  /**
   * Get a model by id.
   */
  getModel(id: string): DefaultModel | undefined {
    return this.models.get(id);
  }

  /**
   * Refresh a model by id.
   * This simulates fetching new data and updating lastRefreshed timestamp.
   */
  async refreshModel(id: string): Promise<DefaultModel> {
    // Simulate fetching new model data (could be from remote or recomputation)
    const newData = await this.fetchModelData(id);
    const refreshedModel: DefaultModel = {
      id,
      data: newData,
      lastRefreshed: Date.now(),
    };
    this.models.set(id, refreshedModel);
    this.saveModel(refreshedModel);
    return refreshedModel;
  }

  /**
   * Refresh all stale models.
   * Returns list of refreshed model ids.
   */
  async refreshStaleModels(): Promise<string[]> {
    const refreshedIds: string[] = [];
    for (const [id, model] of this.models.entries()) {
      if (this.isStale(model)) {
        await this.refreshModel(id);
        refreshedIds.push(id);
      }
    }
    return refreshedIds;
  }

  /**
   * Add a new default model.
   */
  addModel(id: string, data: any) {
    const model: DefaultModel = {
      id,
      data,
      lastRefreshed: Date.now(),
    };
    this.models.set(id, model);
    this.saveModel(model);
  }

  /**
   * Simulate fetching model data.
   * In real implementation, this could be an API call or heavy computation.
   */
  private async fetchModelData(id: string): Promise<any> {
    // For demo, just return a timestamped object
    return {
      refreshedAt: new Date().toISOString(),
      modelId: id,
      info: 'Refreshed model data',
    };
  }
}
