<script setup lang="ts">
import type { Material } from '../types.ts'
import { entriesByKey, entryPath } from '../lib/catalog.ts'
import SpriteCanvas from './SpriteCanvas.vue'
defineProps<{ materials: Material[] }>()
</script>
<template>
  <div class="materials">
    <template v-for="part in materials" :key="part.id">
      <RouterLink
        v-if="entriesByKey.has(`items/${part.id}`)"
        :to="entryPath({ category: 'items', id: part.id })"
        class="material"
      >
        <SpriteCanvas
          :frame="entriesByKey.get(`items/${part.id}`)?.icon"
          :width="38"
          :height="38"
        />
        <span>{{ part.name }}</span>
        <strong>× {{ part.count }}</strong>
      </RouterLink>
      <div v-else class="material">
        <span class="coin">●</span>
        <span>{{ part.name }}</span>
        <strong>× {{ part.count }}</strong>
      </div>
    </template>
  </div>
</template>
