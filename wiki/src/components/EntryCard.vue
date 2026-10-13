<script setup lang="ts">
import type { Entry } from '../types.ts'
import { categories, entryPath } from '../lib/catalog.ts'
import SpriteCanvas from './SpriteCanvas.vue'
import WikiIcon from './WikiIcon.vue'
defineProps<{ entry: Entry; showCategory?: boolean }>()
</script>
<template>
  <RouterLink
    :to="entryPath(entry)"
    class="entry-card"
    :data-entry="`${entry.category}/${entry.id}`"
  >
    <span class="card-art" :class="entry.category">
      <SpriteCanvas
        v-if="entry.icon"
        :frame="entry.icon"
        :tint="entry.tint"
        :width="72"
        :height="86"
      />
      <WikiIcon
        v-else
        :name="categories.find((cat) => cat.id === entry.category)?.icon"
        :size="30"
      />
    </span>
    <span class="card-copy">
      <span class="eyebrow">
        {{
          showCategory ? categories.find((cat) => cat.id === entry.category)?.title : entry.tags[0]
        }}
      </span>
      <h3>{{ entry.title }}</h3>
      <span class="card-summary">{{ entry.summary }}</span>
    </span>
    <WikiIcon name="chevron" :size="16" class="card-arrow" />
    <span v-if="entry.animation && entry.category === 'characters'" class="animation-badge">
      <WikiIcon name="play" :size="11" />
      Анимации
    </span>
  </RouterLink>
</template>
