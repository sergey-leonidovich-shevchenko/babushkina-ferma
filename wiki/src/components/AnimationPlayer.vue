<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { Entry } from '../types.ts'
import SpriteCanvas from './SpriteCanvas.vue'
import WikiIcon from './WikiIcon.vue'

const props = defineProps<{ entry: Entry }>()
const emit = defineEmits<{ close: [] }>()
const modal = ref<HTMLDialogElement>()
const clips = computed(() => props.entry.animation?.clips ?? [])
const action = ref(clips.value.find((clip) => clip.id === 'walk')?.id ?? clips.value[0]?.id ?? '')
const selected = computed(
  () => clips.value.find((clip) => clip.id === action.value) ?? clips.value[0]!
)
const direction = ref(
  selected.value.frames.south
    ? 'south'
    : selected.value.frames.west
      ? 'west'
      : (Object.keys(selected.value.frames)[0] ?? 'south')
)
const frames = computed(
  () => selected.value.frames[direction.value] ?? Object.values(selected.value.frames)[0]!
)
const fitFrames = computed(() => Object.values(selected.value.frames).flat())
const index = ref(0)
const speed = ref(1)
const playing = ref(!matchMedia('(prefers-reduced-motion: reduce)').matches)
const current = computed(() => frames.value[index.value % frames.value.length])
let timer = 0
let start = 0
let from = 0
let previousFocus: HTMLElement | null = null
const compass = [
  { id: 'north-west', title: 'Северо-запад', arrow: '↖' },
  { id: 'north', title: 'Вверх', arrow: '↑' },
  { id: 'north-east', title: 'Северо-восток', arrow: '↗' },
  { id: 'west', title: 'Влево', arrow: '←' },
  { id: 'center', title: 'Точка опоры', arrow: '·' },
  { id: 'east', title: 'Вправо', arrow: '→' },
  { id: 'south-west', title: 'Юго-запад', arrow: '↙' },
  { id: 'south', title: 'Вниз', arrow: '↓' },
  { id: 'south-east', title: 'Юго-восток', arrow: '↘' },
]

/** Продвигает настоящие кадры по времени, а не по частоте обновления экрана. */
function tick(time: number) {
  if (!playing.value || document.hidden) return
  if (!start) start = time
  index.value =
    (from + Math.floor(((time - start) / 1000) * selected.value.fps * speed.value)) %
    frames.value.length
  timer = requestAnimationFrame(tick)
}
/** Перезапускает отсчёт с текущего кадра и отменяет предыдущую цепочку обновлений. */
function restart() {
  cancelAnimationFrame(timer)
  start = 0
  from = index.value
  if (playing.value && !document.hidden) timer = requestAnimationFrame(tick)
}
/** Позволяет изучить позу вручную, не потеряв выбранные действие и направление. */
function step(delta: number) {
  playing.value = false
  index.value = (index.value + delta + frames.value.length) % frames.value.length
}
/** При переключении формы оставляет только реально поддерживаемое направление. */
watch(action, () => {
  if (!selected.value.frames[direction.value])
    direction.value = selected.value.frames.south ? 'south' : Object.keys(selected.value.frames)[0]!
  index.value = 0
  restart()
})
watch(direction, () => {
  index.value = 0
  restart()
})
watch([playing, speed], restart)
onMounted(() => {
  previousFocus = document.activeElement as HTMLElement
  modal.value?.showModal()
  restart()
  document.addEventListener('visibilitychange', restart)
})
onBeforeUnmount(() => {
  cancelAnimationFrame(timer)
  document.removeEventListener('visibilitychange', restart)
  modal.value?.close()
  previousFocus?.focus()
})
</script>
<template>
  <dialog
    ref="modal"
    class="animation-dialog"
    aria-labelledby="animation-title"
    @cancel.prevent="emit('close')"
    @click="
      (event) => {
        if (event.target === modal) emit('close')
      }
    "
  >
    <div class="animation-heading">
      <div>
        <span class="eyebrow">
          {{ entry.category === 'buildings' ? 'РАКУРСЫ И УРОВНИ' : 'ИГРОВЫЕ АНИМАЦИИ' }}
        </span>
        <h2 id="animation-title">{{ entry.title }}</h2>
      </div>
      <button class="icon-button" aria-label="Закрыть просмотр" @click="emit('close')">
        <WikiIcon name="close" />
      </button>
    </div>
    <div class="animation-layout">
      <div
        class="animation-stage"
        data-testid="animation-stage"
        :data-action="action"
        :data-direction="direction"
        :data-frame="index"
      >
        <span class="stage-moon">☾</span>
        <SpriteCanvas
          :frame="current"
          :frames="fitFrames"
          :tint="entry.tint"
          :width="340"
          :height="300"
          shadow
        />
        <span class="stage-caption">{{ selected.title }}</span>
      </div>
      <div class="animation-options">
        <label class="field-label" for="animation-action">Действие</label>
        <select id="animation-action" v-model="action">
          <option v-for="clip in clips" :key="clip.id" :value="clip.id">{{ clip.title }}</option>
        </select>
        <p class="field-label">
          Направление
          <span class="muted">· {{ Object.keys(selected.frames).length }}</span>
        </p>
        <div class="compass" aria-label="Выбор направления">
          <template v-for="point in compass" :key="point.id">
            <span v-if="point.id === 'center'" class="compass-center">
              <WikiIcon name="people" :size="17" />
            </span>
            <button
              v-else
              :disabled="!selected.frames[point.id]"
              :aria-label="point.title"
              :aria-pressed="direction === point.id"
              :class="{ selected: direction === point.id }"
              :title="selected.frames[point.id] ? point.title : 'Отдельного ракурса нет'"
              @click="direction = point.id"
            >
              {{ point.arrow }}
            </button>
          </template>
        </div>
        <label class="field-label" for="animation-speed">Скорость</label>
        <select id="animation-speed" v-model.number="speed" :disabled="frames.length === 1">
          <option :value="0.5">0,5×</option>
          <option :value="1">1×</option>
          <option :value="1.5">1,5×</option>
          <option :value="2">2×</option>
        </select>
      </div>
    </div>
    <div class="animation-controls">
      <button class="button primary" :disabled="frames.length === 1" @click="playing = !playing">
        <WikiIcon :name="playing && frames.length > 1 ? 'pause' : 'play'" :size="17" />
        {{ frames.length === 1 ? 'Один кадр' : playing ? 'Пауза' : 'Запустить' }}
      </button>
      <button
        class="icon-button"
        aria-label="Предыдущий кадр"
        :disabled="frames.length === 1"
        @click="step(-1)"
      >
        ‹
      </button>
      <input
        :value="index"
        type="range"
        min="0"
        :max="frames.length - 1"
        :disabled="frames.length === 1"
        aria-label="Кадр анимации"
        @input="
          (event) => {
            playing = false
            index = Number((event.target as HTMLInputElement).value)
          }
        "
      />
      <button
        class="icon-button"
        aria-label="Следующий кадр"
        :disabled="frames.length === 1"
        @click="step(1)"
      >
        ›
      </button>
      <span class="frame-count">{{ index + 1 }} / {{ frames.length }}</span>
    </div>
    <p class="animation-note">
      Показаны существующие игровые кадры. Неподдерживаемые направления недоступны.
    </p>
  </dialog>
</template>
