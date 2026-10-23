import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';

const root=fileURLToPath(new URL('../../../../',import.meta.url));
const {readPlanningCatalog}=await import(pathToFileURL(join(root,'wiki/scripts/planning-catalog.mjs')));
const {validateAssessments}=await import(pathToFileURL(join(root,'wiki/src/lib/idea-assessment.ts')));
const baseJSON=p=>JSON.parse(execFileSync('git',['show','fe5919686aed1b6ea66cd1112a8075a57d448946:'+p],{cwd:root,encoding:'utf8',maxBuffer:16*1024*1024}));
const json=async p=>JSON.parse(await readFile(p,'utf8'));
const state=await json(root+'/wiki/planning/state.json'), old=baseJSON('wiki/planning/state.json');
const ratings=validateAssessments(await json(root+'/wiki/planning/assessments.json')), oldRatings=baseJSON('wiki/planning/assessments.json');
assert.deepEqual(state.ideas.slice(0,221),old.ideas); assert.deepEqual(state.groups,old.groups); assert.deepEqual(state.epicGroups,old.epicGroups);
assert.deepEqual(ratings.ideas.slice(0,60),oldRatings.ideas);
for(const [k,v] of Object.entries(oldRatings.sources)) assert.deepEqual(ratings.sources[k],v);
const oldIndex=baseJSON('wiki/articles/index.json'), index=await json(root+'/wiki/articles/index.json');assert.deepEqual(index.slice(0,138),oldIndex);
const oldSources=baseJSON('wiki/planning/sources.json'), sources=await json(root+'/wiki/planning/sources.json');
for(let i=0;i<oldSources.plans.length;i++){const expected=structuredClone(oldSources.plans[i]); if(expected.id==='wiki')expected.expected++;assert.deepEqual(sources.plans[i],expected);}
const catalog=await readPlanningCatalog({root,manifest:root+'/wiki/planning/sources.json'});
const ids=new Set(catalog.tasks.map(x=>x.id)); assert.equal(ids.size,catalog.tasks.length);
const byID=new Map(catalog.tasks.map(t=>[t.id,t])), visiting=new Set(), done=new Set();
function visit(id){if(done.has(id))return;assert(!visiting.has(id),`cycle:${id}`);visiting.add(id);for(const d of byID.get(id).dependencies){assert(ids.has(d),`missing:${id}->${d}`);visit(d);}visiting.delete(id);done.add(id);}
for(const id of ids)visit(id);
let future=0;
for(let n=222;n<=231;n++){
 const id=`IDEA-${n}`, plan=`idea-${n}`, idea=state.ideas.find(i=>i.id===id), src=sources.plans.find(p=>p.id===plan), tasks=catalog.tasks.filter(t=>t.plan===plan);
 assert.equal(idea.status,'proposed');assert.equal(idea.group,src.group);assert.deepEqual(idea.linkedEpics,[`${plan}--${id}`]);assert.equal(tasks.length,src.expected);
 const article=await readFile(root+`/wiki/articles/${id}.md`,'utf8');assert(article.includes('## Наблюдаемая приёмка'));assert(article.includes('## Правила'));
 for(const t of tasks){assert.equal(t.status,'backlog');assert(t.acceptance.length>=3);assert(article.includes(`/tasks/${t.key}`));}future+=tasks.length;
 assert(ratings.ideas.find(i=>i.idea===id));
}
assert.equal(future,53);assert.equal(state.ideas.length,231);assert.equal(ratings.ideas.length,70);
assert(!catalog.epics.some(e=>e.id.startsWith('IDEA-DAILY')));
const card=byID.get('IDEA-REVIEW-20261023-EVENING');assert.equal(card.status,'in_progress');
const result={schema:1,checkedAt:new Date().toISOString(),base:'fe5919686aed1b6ea66cd1112a8075a57d448946',preserved:{ideas:221,assessments:60,indexPrefix:138,groups:true,epicGroups:true,sources:90},added:{ideas:10,ownPlans:10,ownEpics:10,futureTasks:future,futureGameScenarios:60,editorialTask:card.id,editorialStatus:card.status},catalog:{plans:catalog.plans.length,epics:catalog.epics.length,tasks:catalog.tasks.length},checks:{uniqueTaskIDs:true,allDependenciesResolve:true,acyclic:true,assessmentSchema:true,oldRecordsDeepEqual:true,ownEpicGroups:true,noDailyGameplayEpics:true},gameplayScenariosExecuted:false};
await writeFile(root+'/docs/reports/creative/2026-10-23-evening/editorial-check.json',JSON.stringify(result,null,2)+'\n'); console.log(JSON.stringify(result));
