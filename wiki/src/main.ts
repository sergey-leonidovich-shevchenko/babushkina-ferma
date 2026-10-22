import { createApp } from 'vue'
import { createRouter, createWebHashHistory } from 'vue-router'
import App from './App.vue'
import HomeView from './views/HomeView.vue'
import ListView from './views/ListView.vue'
import ArticleView from './views/ArticleView.vue'
import DevelopmentView from './views/DevelopmentView.vue'
import legacyLinks from '../planning/legacy-development-links.json'
import { legacyDevelopmentPath } from './lib/idea-assessment.ts'
import './style.css'
import './planning.css'
import './first-location.css'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', component: HomeView },
    { path: '/search', component: ListView },
    {
      path: '/development/:section(first-location|epics|ideas|refinement|tasks|search)/:id?',
      component: DevelopmentView,
    },
    { path: '/development', redirect: '/development/epics' },
    { path: '/:category', component: ListView },
    { path: '/:category/:id', component: ArticleView },
  ],
  scrollBehavior(_to, _from, saved) {
    return saved ?? { top: 0 }
  },
})
router.beforeEach((to) => {
  const path = legacyDevelopmentPath(to.path, legacyLinks)
  if (path) return { path, query: to.query, replace: true }
})
createApp(App).use(router).mount('#app')
