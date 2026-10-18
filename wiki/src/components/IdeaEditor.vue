<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  planning,
  planningSaving,
  changePlanning,
  developmentPath,
  ideaLabels,
  copyPlanningText,
} from '../lib/planning.ts'
import type { IdeaStatus } from '../lib/planning.ts'
import { refreshIdeaDraft } from '../lib/planning-draft.ts'
import type { IdeaDraft } from '../lib/planning-draft.ts'
import WikiIcon from './WikiIcon.vue'

const props = defineProps<{ id: string; queue: boolean }>()
const router = useRouter()
const isNew = computed(() => props.id === 'new')
const idea = computed(() => planning.value!.workspace.ideas.find((item) => item.id === props.id))
const title = ref(''),
  description = ref(''),
  notes = ref(''),
  group = ref('')
const epicQuery = ref(''),
  selectedEpics = ref<string[]>([])
const remoteRefreshed = ref(false)
let previousDraft: IdeaDraft | undefined
let previousId = ''
let savingDraft = false
/** Читает введённые поля отдельно от последней сохранённой карточки. */
function currentDraft(): IdeaDraft {
  return {
    title: title.value,
    description: description.value,
    notes: notes.value,
    group: group.value,
  }
}
/** Применяет обновление формы без потери независимых правок другой вкладки. */
function applyDraft(value: IdeaDraft) {
  title.value = value.title
  description.value = value.description
  notes.value = value.notes
  group.value = value.group
}
const editable = computed(() => !planning.value!.readOnly && !planningSaving.value)
const dirty = computed(
  () =>
    title.value !== idea.value?.title ||
    description.value !== idea.value?.description ||
    notes.value !== (idea.value?.notes ?? '') ||
    group.value !== idea.value?.group
)
const linked = computed(() =>
  planning.value!.catalog.epics.filter(
    (epic) =>
      idea.value?.linkedEpics.includes(epic.key) || idea.value?.linkedPlans?.includes(epic.plan)
  )
)
const epicOptions = computed(() =>
  planning.value!.catalog.epics.filter((epic) =>
    `${epic.id} ${epic.title}`.toLocaleLowerCase().includes(epicQuery.value.toLocaleLowerCase())
  )
)
const brief = computed(
  () =>
    `${idea.value?.id} — ${idea.value?.title}\n\n${idea.value?.description}\n\n` +
    (idea.value?.notes ? `Что учесть:\n${idea.value.notes}\n\n` : '') +
    'Проработай идею и создай эпики и задачи с постоянными ID. Сверь существующие планы и код; ' +
    'опиши результат, границы, зависимости и критерии приёмки. Зарегистрируй эпики в центре разработки ' +
    'и свяжи их с этой идеей. Следуй AGENTS.md и TESTING.md. Это постановка задач, а не готовая реализация.'
)
watch(
  [idea, isNew],
  () => {
    const incoming = {
      title: idea.value?.title ?? '',
      description: idea.value?.description ?? '',
      notes: idea.value?.notes ?? '',
      group: idea.value?.group ?? planning.value!.workspace.groups[0]!.id,
    }
    if (previousId === props.id && previousDraft && !savingDraft) {
      const merged = refreshIdeaDraft(currentDraft(), previousDraft, incoming)
      remoteRefreshed.value =
        JSON.stringify(previousDraft) !== JSON.stringify(incoming) &&
        JSON.stringify(merged) !== JSON.stringify(incoming)
      applyDraft(merged)
    } else {
      applyDraft(incoming)
      remoteRefreshed.value = false
    }
    if (previousId !== props.id) selectedEpics.value = idea.value?.linkedEpics.slice() ?? []
    previousDraft = incoming
    previousId = props.id
  },
  { immediate: true }
)

/** Сохраняет черновик перед сменой статуса, чтобы одобрить именно видимый текст. */
async function save() {
  const previousIds = new Set(planning.value!.workspace.ideas.map((item) => item.id))
  savingDraft = true
  const success = await changePlanning({
    type: isNew.value ? 'create-idea' : 'edit-idea',
    id: props.id,
    title: title.value,
    description: description.value,
    notes: notes.value,
    group: group.value,
  })
  savingDraft = false
  if (success) {
    remoteRefreshed.value = false
    if (!isNew.value && idea.value) {
      applyDraft({
        title: idea.value.title,
        description: idea.value.description,
        notes: idea.value.notes,
        group: idea.value.group,
      })
      previousDraft = currentDraft()
    }
  }
  if (success && isNew.value) {
    const created = planning.value!.workspace.ideas.find((item) => !previousIds.has(item.id))!
    await router.replace(developmentPath('ideas', created.id))
  }
  return success
}
/** Переводит идею по сохранённому редакционному процессу с возможностью возврата. */
async function setStatus(status: IdeaStatus) {
  if (dirty.value && !(await save())) return
  if (await changePlanning({ type: 'set-idea-status', id: props.id, status }))
    router.push(
      developmentPath(['approved', 'refining'].includes(status) ? 'refinement' : 'ideas', props.id)
    )
}
/** Закрывает проработку только после выбора реально существующих эпиков. */
async function linkEpics() {
  const epics = selectedEpics.value.slice()
  if (dirty.value && !(await save())) return
  if (await changePlanning({ type: 'plan-idea', id: props.id, epics }))
    router.push(developmentPath('ideas', props.id))
}
</script>

<template>
  <RouterLink class="planning-back" :to="developmentPath(queue ? 'refinement' : 'ideas')">
    <WikiIcon name="back" :size="17" />
    {{ queue ? 'Очередь проработки' : 'Все идеи' }}
  </RouterLink>
  <div v-if="isNew || idea" class="idea-editor-grid">
    <form class="planning-panel idea-editor" @submit.prevent="save">
      <div class="planning-detail-meta">
        <span class="planning-code">{{ isNew ? 'НОВЫЙ ЗАМЫСЕЛ' : idea!.id }}</span>
        <span v-if="idea" class="planning-status" :class="idea.status">
          {{ ideaLabels[idea.status] }}
        </span>
      </div>
      <h2>{{ isNew ? 'Сохранить новую идею' : 'Замысел и детали' }}</h2>
      <p v-if="remoteRefreshed" class="planning-notice" role="status">
        Данные обновлены. Ваши несохранённые правки оставлены в форме, остальные поля подтянуты из
        проекта.
      </p>
      <label>
        Название
        <input
          v-model="title"
          maxlength="160"
          placeholder="Что хочется добавить в долину?"
          required
          :disabled="!editable"
        />
      </label>
      <label>
        Описание
        <textarea
          v-model="description"
          rows="7"
          maxlength="20000"
          placeholder="Что увидит игрок, как это работает и зачем нужно"
          required
          :disabled="!editable"
        />
      </label>
      <label>
        Направление
        <select v-model="group" :disabled="!editable">
          <option v-for="item in planning!.workspace.groups" :key="item.id" :value="item.id">
            {{ item.title }}
          </option>
        </select>
      </label>
      <label>
        Что учесть при проработке
        <textarea
          v-model="notes"
          rows="4"
          maxlength="20000"
          placeholder="Ограничения, примеры, связи с другими механиками"
          :disabled="!editable"
        />
      </label>
      <div class="planning-detail-actions">
        <button class="button primary" :disabled="!editable || (!isNew && !dirty)">
          {{ isNew ? 'Сохранить идею' : 'Сохранить изменения' }}
        </button>
        <RouterLink v-if="idea?.article" class="text-button" :to="`/guides/${idea.article}`">
          Читать статью
          <WikiIcon name="arrow" :size="15" />
        </RouterLink>
      </div>
    </form>
    <aside v-if="idea" class="idea-side">
      <section class="planning-panel idea-decision">
        <span class="eyebrow">СЛЕДУЮЩИЙ ШАГ</span>
        <h2>{{ idea.status === 'proposed' ? 'Дать идее ход' : ideaLabels[idea.status] }}</h2>
        <p>
          {{
            idea.status === 'proposed'
              ? 'Одобренный замысел попадёт в очередь на подробную проработку.'
              : idea.status === 'planned'
                ? 'Постановка готова. Ход реализации виден в связанных эпиках.'
                : 'Можно уточнить детали, передать замысел агенту или вернуться к нему позже.'
          }}
        </p>
        <button
          v-if="idea.status === 'proposed'"
          type="button"
          class="button primary"
          :disabled="!editable"
          @click="setStatus('approved')"
        >
          <WikiIcon name="check" :size="18" />
          Одобрить к проработке
        </button>
        <button
          v-if="idea.status === 'approved'"
          type="button"
          class="button primary"
          :disabled="!editable"
          @click="setStatus('refining')"
        >
          Начать проработку
          <WikiIcon name="arrow" :size="17" />
        </button>
        <button
          v-if="['approved', 'refining'].includes(idea.status)"
          type="button"
          class="button"
          :disabled="!editable"
          @click="setStatus('proposed')"
        >
          Вернуть в предложения
        </button>
        <button
          v-if="idea.status === 'proposed'"
          type="button"
          class="text-button"
          :disabled="!editable"
          @click="setStatus('archived')"
        >
          Отложить на потом
        </button>
        <button
          v-if="idea.status === 'archived'"
          type="button"
          class="button"
          :disabled="!editable"
          @click="setStatus('proposed')"
        >
          Вернуть в предложения
        </button>
        <button
          v-if="idea.status === 'planned'"
          type="button"
          class="text-button"
          :disabled="!editable"
          @click="setStatus('approved')"
        >
          Вернуть на проработку
        </button>
      </section>
      <section v-if="['approved', 'refining'].includes(idea.status)" class="planning-panel">
        <h3>Передать агенту</h3>
        <p>Скопируйте сохранённый замысел и требования к постановке.</p>
        <button type="button" class="button" @click="copyPlanningText(brief)">
          <WikiIcon name="copy" :size="17" />
          Скопировать задание
        </button>
        <details class="brief-preview">
          <summary>Показать текст задания</summary>
          <p class="planning-prose">{{ brief }}</p>
        </details>
      </section>
      <section v-if="linked.length" class="planning-panel">
        <h3>Связанные эпики</h3>
        <RouterLink
          v-for="epic in linked"
          :key="epic.key"
          class="linked-epic"
          :to="developmentPath('epics', epic.key)"
        >
          <span class="planning-code">{{ epic.id }}</span>
          {{ epic.title }}
          <WikiIcon name="chevron" :size="15" />
        </RouterLink>
      </section>
      <details v-if="idea.history.length" class="planning-panel idea-history">
        <summary>История решений · {{ idea.history.length }}</summary>
        <ol>
          <li v-for="(event, index) in idea.history.slice().reverse()" :key="index">
            <time>{{ new Date(event.at).toLocaleString('ru-RU') }}</time>
            {{
              event.type === 'created'
                ? 'Идея сохранена'
                : event.type === 'edited'
                  ? 'Детали обновлены'
                  : `${ideaLabels[event.from as IdeaStatus]} → ${ideaLabels[event.to as IdeaStatus]}`
            }}
          </li>
        </ol>
      </details>
    </aside>
    <section
      v-if="idea && ['approved', 'refining'].includes(idea.status)"
      class="planning-panel idea-link-panel"
    >
      <div>
        <span class="eyebrow">ПОСЛЕ ПРОРАБОТКИ</span>
        <h2>Связать с готовыми эпиками</h2>
        <p>
          Когда карточки задач уже созданы, выберите их эпики. Идея перейдёт в «Задачи созданы»;
          статусы самих задач останутся прежними.
        </p>
      </div>
      <label>
        Найти эпик
        <input v-model="epicQuery" placeholder="Название или ID" />
      </label>
      <div class="epic-picker">
        <label v-for="epic in epicOptions" :key="epic.key">
          <input v-model="selectedEpics" type="checkbox" :value="epic.key" :disabled="!editable" />
          <span>
            <span class="planning-code">{{ epic.id }}</span>
            {{ epic.title }}
          </span>
        </label>
        <p v-if="!epicOptions.length">По этому запросу эпиков нет.</p>
      </div>
      <button
        class="button primary"
        :disabled="!editable || !selectedEpics.length"
        @click="linkEpics"
      >
        Задачи созданы · {{ selectedEpics.length }}
      </button>
    </section>
  </div>
  <div v-else class="empty-state">
    <h2>Идея не найдена</h2>
    <p>Обновите список или вернитесь к предложениям.</p>
  </div>
</template>
