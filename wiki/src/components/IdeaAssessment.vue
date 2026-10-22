<script setup lang="ts">
import { computed } from 'vue'
import records from '../../planning/assessments.json'
import { assessmentFor } from '../lib/idea-assessment.ts'

const props = defineProps<{ id: string; detailed?: boolean }>()
const row = computed(() => assessmentFor(records, props.id))
const confidence = {
  hypothesis: 'Дизайнерская гипотеза',
  pilot: 'После прототипа',
  validated: 'Проверено игровой пробой',
}
</script>

<template>
  <section v-if="row" class="idea-assessment" :aria-label="`Оценка ${id}`">
    <p class="assessment-caption">{{ confidence[row.confidence as keyof typeof confidence] }}</p>
    <dl class="assessment-metrics">
      <div>
        <dt>Польза</dt>
        <dd>{{ row.usefulness }} / 5</dd>
      </div>
      <div>
        <dt>Интерес</dt>
        <dd>{{ row.interest }} / 5</dd>
      </div>
      <div>
        <dt>Стоимость</dt>
        <dd>{{ row.cost }} / 5</dd>
      </div>
      <template v-if="detailed">
        <div>
          <dt>Соответствие игре</dt>
          <dd>{{ row.fit }} / 5</dd>
        </div>
        <div>
          <dt>Связи систем</dt>
          <dd>{{ row.synergy }} / 5</dd>
        </div>
        <div>
          <dt>Риск</dt>
          <dd>{{ row.risk }} / 5</dd>
        </div>
      </template>
    </dl>
    <template v-if="detailed">
      <p>
        <strong>Для кого:</strong>
        {{ row.audience }}.
      </p>
      <p>{{ row.rationale }}</p>
      <p>
        <strong>Проверка прототипа:</strong>
        {{ row.prototype }}
      </p>
      <p>
        <strong>Аналоги:</strong>
        {{ row.analogue }}
      </p>
      <p class="assessment-caption">
        {{ row.reviewedAt }} · Оценки не меняют статус идеи и приоритет первой локации.
      </p>
    </template>
    <RouterLink v-if="detailed" class="text-button" to="/guides/idea-assessment-method">
      Как читать оценки
    </RouterLink>
  </section>
  <p v-else-if="detailed" class="assessment-caption">
    Оценка пока не подготовлена. Это не нулевая полезность.
  </p>
</template>

<style scoped>
.idea-assessment {
  min-width: 0;
  margin: 0.8rem 0;
}
.assessment-caption {
  font-size: 0.78rem;
  color: var(--muted, #6f654e);
  margin: 0.35rem 0;
}
.assessment-metrics {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
  margin: 0.5rem 0;
}
.assessment-metrics div {
  min-width: 4.5rem;
}
.assessment-metrics dt {
  font-size: 0.75rem;
}
.assessment-metrics dd {
  margin: 0.15rem 0 0;
  font-weight: 700;
}
.idea-assessment p {
  overflow-wrap: anywhere;
}
</style>
