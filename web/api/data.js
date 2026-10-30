// GET /api/data - everything the portal shows (read-only).
import { sb, ghl, ghlLocation, send } from './_lib.js';

async function pipeline() {
  try {
    const { pipelines } = await ghl(`/opportunities/pipelines?locationId=${ghlLocation()}`);
    const p = (pipelines || []).find((x) => x.name.trim().toLowerCase() === 'ge-rc candidates');
    if (!p) return { ready: false, stages: [] };
    const { opportunities } = await ghl(`/opportunities/search?location_id=${ghlLocation()}&pipeline_id=${p.id}&limit=100`);
    const stages = p.stages.map((s) => ({
      name: s.name,
      people: (opportunities || []).filter((o) => o.pipelineStageId === s.id).map((o) => ({
        name: (o.contact && o.contact.name) || o.name, deal: o.name, since: o.lastStageChangeAt || o.updatedAt || o.createdAt,
      })),
    }));
    return { ready: true, stages };
  } catch (e) {
    return { ready: false, stages: [], error: e.message };
  }
}

export default async function handler(req, res) {
  try {
    const [roles, shortlists, candidates, cvLog, tests, ghlPipe] = await Promise.all([
      sb('roles?select=id,client,title,status,jd_text,search_query,decided_by,decided_at,created_at&order=id.desc'),
      sb('shortlists?select=role_id,rank,score,reason,cv_file,status,decided_by,decided_at,candidate:candidates(name,location)&order=role_id,rank'),
      sb('candidates?select=id,name,location,headline,languages,cv_file,cv_date,updated_at&order=name'),
      sb('cv_files?select=file_name,outcome,detail,received_at&order=id.desc&limit=300'),
      sb('test_runs?select=ran_at,score,total,details&order=id.desc&limit=1'),
      pipeline(),
    ]);
    for (const r of roles) r.shortlist = shortlists.filter((s) => s.role_id === r.id);
    send(res, 200, { roles, candidates, cvLog, test: tests[0] || null, pipeline: ghlPipe });
  } catch (e) {
    send(res, 500, { error: e.message });
  }
}
