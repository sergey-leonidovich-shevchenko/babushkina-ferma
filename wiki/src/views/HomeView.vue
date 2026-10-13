<script setup lang="ts">
import { catalog, categories, entriesByKey, entryPath, assetUrl } from '../lib/catalog.ts'
import EntryCard from '../components/EntryCard.vue'
import WikiIcon from '../components/WikiIcon.vue'
import type { Category } from '../types.ts'
const featured = [
  'characters/agafya',
  'characters/deep_guardian',
  'buildings/station-furnace',
  'buildings/station-pottery',
  'buildings/station-alchemy',
  'locations/village_orchard',
]
const firstDay = 'missions/chapter-0'
const stats: Category[] = ['characters', 'missions', 'craft', 'items']
</script>
<template>
  <div class="page home-page">
    <div class="welcome-heading">
      <div>
        <span class="eyebrow">ЭНЦИКЛОПЕДИЯ ИГРЫ</span>
        <h1>Путеводитель по долине</h1>
        <p>Всё о жителях, приключениях и жизни на ферме — в одном месте.</p>
      </div>
      <span class="edition">
        <WikiIcon name="moon" />
        Лунная долина
      </span>
    </div>
    <section
      class="welcome-banner"
      :style="{
        backgroundImage: `linear-gradient(90deg, #18382bfa 0%, #18382bbf 52%, #18382b20 100%), url(${assetUrl(catalog!.cover)})`,
      }"
    >
      <div>
        <span class="eyebrow">НОВАЯ ИСТОРИЯ НАЧИНАЕТСЯ ДОМА</span>
        <h2>
          Первый день
          <br />
          на бабушкиной ферме
        </h2>
        <p>
          От разговора у дома до первого урожая.
          <br />
          Найдите свой путь в Лунной долине.
        </p>
        <RouterLink
          v-if="entriesByKey.has(firstDay)"
          :to="entryPath(entriesByKey.get(firstDay)!)"
          class="button warm"
        >
          Первые шаги
          <WikiIcon name="arrow" :size="17" />
        </RouterLink>
      </div>
      <span class="banner-mark">☾</span>
    </section>
    <div class="catalog-stats">
      <RouterLink v-for="id in stats" :key="id" :to="`/${id}`">
        <strong>{{ catalog!.meta.counts[id] }}</strong>
        <span>{{ categories.find((cat) => cat.id === id)?.title }}</span>
        <WikiIcon name="arrow" :size="16" />
      </RouterLink>
    </div>
    <div class="section-heading">
      <h2>Исследуйте справочник</h2>
      <span class="muted">{{ catalog!.entries.length }} статей</span>
    </div>
    <div class="category-grid">
      <RouterLink
        v-for="category in categories"
        :key="category.id"
        :to="`/${category.id}`"
        class="category-card"
      >
        <span class="category-icon"><WikiIcon :name="category.icon" :size="25" /></span>
        <div>
          <h3>{{ category.title }}</h3>
          <p>{{ category.description }}</p>
        </div>
        <span class="category-count">{{ catalog!.meta.counts[category.id] }}</span>
      </RouterLink>
    </div>
    <div class="section-heading">
      <h2>Знакомые лица и новые занятия</h2>
      <RouterLink to="/characters">
        Все персонажи
        <WikiIcon name="arrow" :size="15" />
      </RouterLink>
    </div>
    <div class="entry-grid">
      <template v-for="key in featured" :key="key">
        <EntryCard v-if="entriesByKey.has(key)" :entry="entriesByKey.get(key)!" show-category />
      </template>
    </div>
  </div>
</template>
