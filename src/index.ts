import path from 'path';
import { DefaultModelManager } from './models/defaultModelManager';

const MODEL_STORAGE_PATH = path.join(__dirname, '../models_storage');
const STALE_THRESHOLD_MS = 24 * 60 * 60 * 1000; // 24 hours

async function main() {
  const modelManager = new DefaultModelManager({
    staleThresholdMs: STALE_THRESHOLD_MS,
    modelStoragePath: MODEL_STORAGE_PATH,
  });

  console.log('Checking for stale default models...');
  const refreshed = await modelManager.refreshStaleModels();
  if (refreshed.length > 0) {
    console.log(`Refreshed stale models: ${refreshed.join(', ')}`);
  } else {
    console.log('No stale models found.');
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Error refreshing models:', err);
    process.exit(1);
  });
}
