import { createApp } from 'vue'
import { createRouter, createWebHashHistory } from 'vue-router'
import App from './App.vue'
import HomeView from './views/HomeView.vue'
import ListView from './views/ListView.vue'
import ArticleView from './views/ArticleView.vue'
import DevelopmentView from './views/DevelopmentView.vue'
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
createApp(App).use(router).mount('#app')
