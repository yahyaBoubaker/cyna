import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Sur Docker Desktop (Windows), les événements de fichiers du bind-mount
// n'arrivent pas toujours jusqu'au watcher de Vite dans le conteneur Linux.
// Le polling force Vite à vérifier les fichiers à intervalle régulier,
// pour que les modifications soient bien prises en compte (HMR).
export default defineConfig({
  plugins: [react()],
  server: {
    watch: {
      usePolling: true,
      interval: 300,
    },
  },
});
