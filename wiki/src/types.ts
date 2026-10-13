export type Category =
  | 'characters'
  | 'missions'
  | 'buildings'
  | 'craft'
  | 'items'
  | 'plants'
  | 'locations'
  | 'skills'
  | 'fishing'
  | 'guides'
export interface Material {
  id: string
  name: string
  count: number
}
export interface SpriteFrame {
  image: string
  rect: [number, number, number, number]
  pivot: [number, number]
  scale: number
  flip: boolean
}
export interface AnimationClip {
  id: string
  title: string
  fps: number
  frames: Record<string, SpriteFrame[]>
}
export interface Entry {
  id: string
  category: Category
  title: string
  summary: string
  tags: string[]
  facts: { label: string; value: string }[]
  sections: { title: string; text: string }[]
  relations: { category: Category; id: string; label: string; group: string }[]
  ingredients: Material[]
  yields: Material[]
  byproducts?: Material[]
  salvage?: Material[]
  icon?: SpriteFrame
  tint?: string
  animation?: { clips: AnimationClip[] }
  levels?: { level: number; coins: number; seconds: number; ingredients: Material[] }[]
  station?: string
  output?: string
  html?: string
  source: string
}
export interface Catalog {
  schema: number
  entries: Entry[]
  images: Record<string, [number, number]>
  cover: string
  meta: { version: string; counts: Record<Category, number> }
  coverage: Record<string, number>
}
