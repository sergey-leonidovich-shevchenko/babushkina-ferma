<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { SpriteFrame } from '../types.ts'
import { assetUrl } from '../lib/catalog.ts'

const props = withDefaults(
  defineProps<{
    frame?: SpriteFrame
    frames?: SpriteFrame[]
    tint?: string
    width?: number
    height?: number
    shadow?: boolean
  }>(),
  { width: 64, height: 64, shadow: false }
)
const canvas = ref<HTMLCanvasElement>()
const failed = ref(false)
let revision = 0
const images = new Map<string, Promise<HTMLImageElement>>()

/** Читает каждый спрайт один раз на экземпляр и сохраняет ошибку для доступного резервного отображения. */
function load(path: string) {
  if (!images.has(path))
    images.set(
      path,
      new Promise((accept, reject) => {
        const image = new Image()
        image.onload = () => accept(image)
        image.onerror = reject
        image.src = assetUrl(path)
      })
    )
  return images.get(path)!
}

/** Рисует кадр с фактической опорой и общим масштабом всех фаз, защищая быстрый выбор от гонки загрузок. */
async function paint() {
  const current = ++revision
  const target = canvas.value
  const frame = props.frame
  if (!target || !frame) return
  const ratio = Math.min(devicePixelRatio || 1, 2)
  target.width = props.width * ratio
  target.height = props.height * ratio
  const context = target.getContext('2d')
  if (!context) return
  context.setTransform(ratio, 0, 0, ratio, 0, 0)
  context.clearRect(0, 0, props.width, props.height)
  try {
    const image = await load(frame.image)
    if (current !== revision) return
    let left = Infinity
    let right = -Infinity
    let top = Infinity
    let bottom = -Infinity
    for (const value of props.frames?.length ? props.frames : [frame]) {
      left = Math.min(left, -value.pivot[0] * value.scale)
      right = Math.max(right, (value.rect[2] - value.pivot[0]) * value.scale)
      top = Math.min(top, -value.pivot[1] * value.scale)
      bottom = Math.max(bottom, (value.rect[3] - value.pivot[1]) * value.scale)
    }
    if (props.shadow) bottom = Math.max(bottom, 14)
    const factor = Math.min(
      (props.width - 12) / Math.max(1, right - left),
      (props.height - 12) / Math.max(1, bottom - top)
    )
    const groundX = props.width / 2 - ((left + right) / 2) * factor
    const groundY = props.height / 2 - ((top + bottom) / 2) * factor
    if (props.shadow) {
      context.fillStyle = '#163b2924'
      context.beginPath()
      context.ellipse(
        groundX,
        groundY + 3,
        Math.min(34, 18 * factor),
        Math.min(9, 5 * factor),
        0,
        0,
        Math.PI * 2
      )
      context.fill()
    }
    const [x, y, width, height] = frame.rect
    const scale = frame.scale * factor
    let source: CanvasImageSource = image
    let sourceX = x
    let sourceY = y
    if (props.tint && props.tint !== 'ffffff') {
      const colored = document.createElement('canvas')
      colored.width = width
      colored.height = height
      const color = colored.getContext('2d')!
      color.drawImage(image, x, y, width, height, 0, 0, width, height)
      color.globalCompositeOperation = 'multiply'
      color.fillStyle = `#${props.tint}`
      color.fillRect(0, 0, width, height)
      color.globalCompositeOperation = 'destination-in'
      color.drawImage(image, x, y, width, height, 0, 0, width, height)
      source = colored
      sourceX = 0
      sourceY = 0
    }
    context.save()
    context.imageSmoothingEnabled = scale < 1
    context.translate(
      groundX - frame.pivot[0] * scale + (frame.flip ? width * scale : 0),
      groundY - frame.pivot[1] * scale
    )
    context.scale(frame.flip ? -scale : scale, scale)
    context.drawImage(source, sourceX, sourceY, width, height, 0, 0, width, height)
    context.restore()
    failed.value = false
  } catch {
    if (current === revision) failed.value = true
  }
}
onMounted(paint)
watch(() => [props.frame, props.tint, props.width, props.height], paint)
onBeforeUnmount(() => {
  revision++
  images.clear()
})
</script>
<template>
  <span class="sprite" :style="{ width: `${width}px`, height: `${height}px` }">
    <canvas
      ref="canvas"
      :style="{ width: `${width}px`, height: `${height}px` }"
      aria-hidden="true"
    />
    <span v-if="failed" class="sprite-fallback" title="Не удалось прочитать кадр">◇</span>
  </span>
</template>
