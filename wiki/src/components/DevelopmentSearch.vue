<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { planning, matchesQuery, developmentPath, ideaLabels, taskLabels } from '../lib/planning.ts'
import WikiIcon from './WikiIcon.vue'
const route = useRoute()
const query = computed(() => String(route.query.q ?? '').trim())
const results = computed(() => [
  {
    id: 'ideas',
    title: 'Идеи',
    items: planning
      .value!.workspace.ideas.filter((item) =>
        matchesQuery(query.value, item.id, item.title, item.description, item.notes)
      )
      .map((item) => ({
        key: item.id,
        title: item.title,
        code: item.id,
        status: ideaLabels[item.status],
      })),
  },
  {
    id: 'epics',
    title: 'Эпики',
    items: planning
      .value!.catalog.epics.filter((item) =>
        matchesQuery(query.value, item.id, item.title, item.goal)
      )
      .map((item) => ({ key: item.key, title: item.title, code: item.id, status: '' })),
  },
  {
    id: 'tasks',
    title: 'Задачи',
    items: planning
      .value!.catalog.tasks.filter((item) =>
        matchesQuery(query.value, item.id, item.title, item.goal)
      )
      .map((item) => ({
        key: item.key,
        title: item.title,
        code: item.id,
        status: taskLabels[item.status],
      })),
  },
])
const total = computed(() => results.value.reduce((sum, group) => sum + group.items.length, 0))
</script>

<template>
  <div v-if="!query" class="empty-state">
    <WikiIcon name="search" :size="40" />
    <h2>Что найдём в планах?</h2>
    <p>Введите название, ID или часть замысла в строке поиска сверху.</p>
  </div>
  <template v-else>
    <p class="planning-results-count">«{{ query }}» · результатов: {{ total }}</p>
    <section
      v-for="group in results.filter((item) => item.items.length)"
      :key="group.id"
      class="planning-search-section"
    >
      <div class="section-heading">
        <h2>{{ group.title }}</h2>
        <RouterLink :to="{ path: developmentPath(group.id), query: { q: query } }">
          Все результаты · {{ group.items.length }}
        </RouterLink>
      </div>
      <div class="planning-task-list">
        <RouterLink
          v-for="item in group.items.slice(0, 10)"
          :key="item.key"
          :to="developmentPath(group.id, item.key)"
          class="planning-search-result"
        >
          <span class="planning-code">{{ item.code }}</span>
          <span>{{ item.title }}</span>
          <small>{{ item.status }}</small>
          <WikiIcon name="chevron" :size="16" />
        </RouterLink>
      </div>
    </section>
    <div v-if="!total" class="empty-state">
      <WikiIcon name="search" :size="40" />
      <h2>Ничего не найдено</h2>
      <p>Попробуйте другой запрос или точный ID карточки.</p>
    </div>
  </template>
</template>
