<script setup lang="ts">
withDefaults(defineProps<{ name?: string; size?: number }>(), { name: 'book', size: 20 })
const paths: Record<string, string> = {
  book: 'M12 6C8 3 5 3 2 4v15c3-1 6-1 10 2 4-3 7-3 10-2V4c-3-1-6-1-10 2Zm0 0v15',
  home: 'm3 10 9-7 9 7M5 9v12h14V9M9 21v-7h6v7',
  people:
    'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2m20 0v-2a4 4 0 0 0-3-4M9 3a4 4 0 1 1 0 8 4 4 0 0 1 0-8Zm8 0a4 4 0 0 1 0 8',
  scroll:
    'M8 3h11v16a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3v-2h10v2a3 3 0 0 0 6 0M8 3v8H3V6a3 3 0 0 1 6 0M11 7h5m-5 4h5',
  house: 'm2 11 10-8 10 8M4 10v11h16V10M8 21v-8h8v8',
  hammer: 'm14 5-7 7 5 5 7-7-5-5Zm-7 7-5 5 5 5 5-5M14 5l3-3 5 5-3 3',
  bag: 'M5 7h14l2 15H3L5 7Zm3 0V5a4 4 0 0 1 8 0v2M8 11h8',
  leaf: 'M20 3C8 2 2 7 4 15c2 8 14 6 16-12ZM3 22l12-12',
  map: 'm9 3-7 3v16l7-3 6 3 7-3V3l-7 3-6-3Zm0 0v16m6-13v16',
  spark: 'm12 2 3 7 7 3-7 3-3 7-3-7-7-3 7-3 3-7Z',
  fish: 'M18 12C13 2 4 4 2 12c2 8 11 10 16 0l4 5V7l-4 5ZM7 10h.01m1-5 2 7-2 7',
  search: 'M11 3a8 8 0 1 1 0 16 8 8 0 0 1 0-16Zm6 14 5 5',
  arrow: 'M5 12h14m-6-6 6 6-6 6',
  back: 'M19 12H5m6-6-6 6 6 6',
  play: 'm8 4 12 8-12 8V4Z',
  pause: 'M8 4v16m8-16v16',
  close: 'm6 6 12 12M6 18 18 6',
  menu: 'M3 6h18M3 12h18M3 18h18',
  moon: 'M20 15a9 9 0 0 1-11-11 9 9 0 1 0 11 11Z',
  copy: 'M8 8h13v13H8V8ZM16 4V2H2v14h2',
  chevron: 'm9 5 7 7-7 7',
  grid: 'M3 3h7v7H3V3Zm11 0h7v7h-7V3ZM3 14h7v7H3v-7Zm11 0h7v7h-7v-7Z',
}
</script>
<template>
  <svg
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.6"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path :d="paths[name] ?? paths.book" />
  </svg>
</template>
