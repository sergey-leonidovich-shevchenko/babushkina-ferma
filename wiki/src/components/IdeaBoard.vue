<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  planning,
  planningSaving,
  refinementIdeas,
  ideaLabels,
  changePlanning,
  developmentPath,
  matchesQuery,
} from '../lib/planning.ts'
import WikiIcon from './WikiIcon.vue'
import IdeaEditor from './IdeaEditor.vue'

const props = defineProps<{ queue: boolean }>()
const route = useRoute(),
  router = useRouter()
const query = computed(() => String(route.query.q ?? ''))
const status = computed(() => String(route.query.status ?? ''))
const group = computed(() => String(route.query.group ?? ''))
const ideas = computed(() =>
  (props.queue ? refinementIdeas.value : planning.value!.workspace.ideas)
    .filter(
      (idea) =>
        (!status.value || idea.status === status.value) &&
        (!group.value || idea.group === group.value) &&
        matchesQuery(query.value, idea.id, idea.title, idea.description, idea.notes)
    )
    .slice()
    .sort((a, b) => b.id.localeCompare(a.id, 'ru', { numeric: true }))
)
/** После подтверждённой записи открывает очередь, а не оставляет локальную имитацию одобрения. */
async function approve(id: string) {
  if (await changePlanning({ type: 'set-idea-status', id, status: 'approved' }))
    router.push(developmentPath('refinement', id))
}
</script>

<template>
  <IdeaEditor v-if="route.params.id" :id="String(route.params.id)" :queue="queue" />
  <template v-else>
    <div class="planning-toolbar">
      <label class="planning-search">
        <WikiIcon name="search" :size="18" />
        <input
          :value="query"
          placeholder="Название или содержание идеи"
          aria-label="Поиск идей"
          @input="
            router.replace({
              query: { ...route.query, q: ($event.target as HTMLInputElement).value || undefined },
            })
          "
        />
      </label>
      <label class="planning-select">
        Состояние
        <select
          :value="status"
          @change="
            router.replace({
              query: {
                ...route.query,
                status: ($event.target as HTMLSelectElement).value || undefined,
              },
            })
          "
        >
          <option value="">{{ queue ? 'Вся очередь' : 'Все идеи' }}</option>
          <option
            v-for="(label, id) in ideaLabels"
            v-show="!queue || ['approved', 'refining'].includes(id)"
            :key="id"
            :value="id"
          >
            {{ label }}
          </option>
        </select>
      </label>
      <label class="planning-select">
        Группа
        <select
          :value="group"
          @change="
            router.replace({
              query: {
                ...route.query,
                group: ($event.target as HTMLSelectElement).value || undefined,
              },
            })
          "
        >
          <option value="">Все группы</option>
          <option v-for="item in planning!.workspace.groups" :key="item.id" :value="item.id">
            {{ item.title }}
          </option>
        </select>
      </label>
      <RouterLink
        v-if="!queue && !planning!.readOnly"
        class="button primary"
        to="/development/ideas/new"
      >
        <WikiIcon name="plus" :size="17" />
        Новая идея
      </RouterLink>
    </div>
    <div v-if="queue" class="refinement-intro">
      <WikiIcon name="spark" :size="27" />
      <p>
        Одобрение отправляет замысел на подробную проработку. Когда агент подготовит карточки,
        свяжите их с идеей — она перейдёт в «Задачи созданы».
      </p>
    </div>
    <div class="idea-grid">
      <article v-for="idea in ideas" :key="idea.id" class="idea-card">
        <div class="epic-card-top">
          <span class="planning-code">{{ idea.id }}</span>
          <span class="planning-status" :class="idea.status">{{ ideaLabels[idea.status] }}</span>
        </div>
        <RouterLink :to="developmentPath(queue ? 'refinement' : 'ideas', idea.id)">
          <h2>{{ idea.title }}</h2>
        </RouterLink>
        <p>{{ idea.description }}</p>
        <span class="idea-group">
          <WikiIcon name="layers" :size="14" />
          {{ planning!.workspace.groups.find((group) => group.id === idea.group)?.title }}
        </span>
        <div class="idea-card-actions">
          <button
            v-if="idea.status === 'proposed'"
            class="button primary"
            :disabled="planning!.readOnly || planningSaving"
            @click="approve(idea.id)"
          >
            <WikiIcon name="check" :size="16" />
            Одобрить
          </button>
          <RouterLink class="button" :to="developmentPath(queue ? 'refinement' : 'ideas', idea.id)">
            {{ queue ? 'Проработать идею' : 'Открыть идею' }}
            <WikiIcon name="arrow" :size="16" />
          </RouterLink>
        </div>
      </article>
    </div>
    <div v-if="!ideas.length" class="empty-state planning-empty">
      <span class="planning-empty-orbit">
        <WikiIcon :name="queue ? 'spark' : 'bulb'" :size="35" />
      </span>
      <h2>{{ queue ? 'Всё начинается с идеи' : 'Пока ничего не найдено' }}</h2>
      <p>
        {{
          queue
            ? 'Нажмите «Одобрить» у понравившейся идеи — она появится здесь и будет готова к передаче агенту.'
            : 'Измените поиск или сохраните новый замысел.'
        }}
      </p>
      <RouterLink v-if="queue" class="button" to="/development/ideas">
        Посмотреть идеи
        <WikiIcon name="arrow" :size="16" />
      </RouterLink>
    </div>
  </template>
</template>
