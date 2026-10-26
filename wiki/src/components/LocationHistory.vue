<script setup lang="ts">
import type { PlanTask } from '../lib/planning.ts'
import { developmentPath } from '../lib/planning.ts'

defineProps<{ tasks: (PlanTask & { context: string })[] }>()
</script>

<template>
  <section class="planning-panel location-history" aria-labelledby="location-history-title">
    <h2 id="location-history-title">История выполненного</h2>
    <p class="muted">
      Завершённые задачи маршрута и его технического обслуживания · {{ tasks.length }}. Новые даты
      сверху; без подтверждённой даты — в конце. Это история работы, а не процент приёмки всей
      карты.
    </p>
    <ol v-if="tasks.length" class="location-history-list" aria-label="Завершённые задачи">
      <li v-for="task in tasks" :key="task.key" :data-task-key="task.key">
        <div class="location-history-date">
          <time v-if="task.completion?.date" :datetime="task.completion.date">
            {{ task.completion.date.split('-').reverse().join('.') }}
          </time>
          <span v-else>Дата не указана</span>
          <small v-if="task.completion?.date">{{ task.completion.basis }}</small>
        </div>
        <div class="location-history-entry">
          <RouterLink :to="developmentPath('tasks', task.key)">
            <span class="planning-code">{{ task.id }}</span>
            <strong>{{ task.title }}</strong>
          </RouterLink>
          <p class="muted">{{ task.context }}</p>
          <details v-if="task.completion?.evidence.length">
            <summary>Материалы и подтверждения · {{ task.completion.evidence.length }}</summary>
            <ul>
              <li v-for="proof in task.completion.evidence" :key="proof.url">
                <a :href="proof.url">{{ proof.label }}</a>
              </li>
            </ul>
          </details>
        </div>
      </li>
    </ol>
    <p v-else class="muted">В маршруте и его техническом обслуживании ещё нет завершённых задач.</p>
  </section>
</template>
