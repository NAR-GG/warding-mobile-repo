#!/usr/bin/env python3
"""Minimal OKF bundle visualizer — emits a self-contained interactive HTML graph.
A proof-of-concept *consumer* of OKF: parses markdown+frontmatter, builds the
cross-link graph, and renders force-directed graph + detail panel + backlinks +
search + type filter. No external dependencies, no backend.
"""
import json, os, re, sys

BUNDLE = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(BUNDLE, "viz.html")
NAME = sys.argv[3] if len(sys.argv) > 3 else os.path.basename(os.path.abspath(BUNDLE.rstrip("/")))

RESERVED = {"index.md", "log.md"}

def parse_frontmatter(text):
    fm, body = {}, text
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            raw = text[3:end].strip("\n")
            body = text[end+4:].lstrip("\n")
            key = None
            for line in raw.split("\n"):
                m = re.match(r"^([A-Za-z_]+):\s*(.*)$", line)
                if m:
                    key, val = m.group(1), m.group(2).strip()
                    if val.startswith("[") and val.endswith("]"):
                        fm[key] = [t.strip() for t in val[1:-1].split(",") if t.strip()]
                    else:
                        fm[key] = val
    return fm, body

nodes, edges = [], []
ids = set()
# first pass: collect concepts
files = []
for root, _, fnames in os.walk(BUNDLE):
    for fn in fnames:
        if not fn.endswith(".md"):
            continue
        full = os.path.join(root, fn)
        rel = os.path.relpath(full, BUNDLE)
        cid = rel[:-3]  # strip .md
        files.append((full, rel, cid, fn))
        if fn not in RESERVED:
            ids.add(cid)

LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")

for full, rel, cid, fn in files:
    if fn in RESERVED:
        continue
    with open(full, encoding="utf-8") as f:
        text = f.read()
    fm, body = parse_frontmatter(text)
    title = fm.get("title") or os.path.basename(cid)
    nodes.append({
        "id": cid,
        "title": title,
        "type": fm.get("type", "Concept"),
        "description": fm.get("description", ""),
        "resource": fm.get("resource", ""),
        "tags": fm.get("tags", []) if isinstance(fm.get("tags"), list) else [],
        "body": body,
    })
    # extract links
    cur_dir = os.path.dirname(cid)
    for _label, href in LINK_RE.findall(body):
        if not href.endswith(".md"):
            continue
        if href.startswith("/"):
            target = href[1:-3]
        elif href.startswith("http"):
            continue
        else:
            target = os.path.normpath(os.path.join(cur_dir, href))[:-3] if False else os.path.normpath(os.path.join(cur_dir, href[:-3]))
        if target in ids and target != cid:
            edges.append({"source": cid, "target": target})

# dedupe edges
seen = set()
uedges = []
for e in edges:
    k = (e["source"], e["target"])
    if k not in seen:
        seen.add(k); uedges.append(e)

data = {"name": NAME, "nodes": nodes, "edges": uedges}

HTML = r"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__NAME__ — OKF</title>
<style>
  :root{--bg:#0d1117;--panel:#161b22;--line:#30363d;--text:#e6edf3;--muted:#8b949e;--accent:#2f81f7;}
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:var(--bg);color:var(--text);font:14px/1.55 -apple-system,"Apple SD Gothic Neo","Pretendard",sans-serif;height:100vh;overflow:hidden}
  #app{display:flex;height:100vh}
  #left{flex:1;position:relative;min-width:0}
  #right{width:420px;max-width:46vw;border-left:1px solid var(--line);background:var(--panel);overflow-y:auto;padding:20px}
  canvas{display:block;width:100%;height:100%}
  #topbar{position:absolute;top:12px;left:12px;right:12px;display:flex;gap:8px;align-items:center;z-index:5;flex-wrap:wrap}
  #topbar .title{font-weight:700;font-size:15px;margin-right:8px}
  input,select{background:var(--panel);color:var(--text);border:1px solid var(--line);border-radius:7px;padding:6px 10px;font-size:13px}
  input{width:200px}
  .legend{position:absolute;bottom:12px;left:12px;z-index:5;background:rgba(22,27,34,.85);border:1px solid var(--line);border-radius:8px;padding:8px 10px;font-size:12px;max-width:60%}
  .legend span{display:inline-flex;align-items:center;margin:2px 8px 2px 0}
  .dot{width:10px;height:10px;border-radius:50%;display:inline-block;margin-right:5px}
  .kicker{color:var(--accent);font-size:11px;letter-spacing:.12em;text-transform:uppercase;font-weight:700}
  #right h1{font-size:20px;margin:6px 0 4px}
  #right .desc{color:var(--muted);margin-bottom:12px}
  #right .meta{font-size:12px;color:var(--muted);margin-bottom:14px}
  .tag{display:inline-block;border:1px solid var(--line);border-radius:999px;padding:1px 8px;margin:2px 4px 2px 0;font-size:11px;color:var(--muted)}
  .body{border-top:1px solid var(--line);padding-top:14px;font-size:13px}
  .body h1,.body h2{font-size:15px;margin:14px 0 6px;border:0}
  .body h1{font-size:16px}
  .body table{border-collapse:collapse;width:100%;margin:8px 0;font-size:12px;display:block;overflow-x:auto}
  .body th,.body td{border:1px solid var(--line);padding:4px 8px;text-align:left}
  .body code{background:#21262d;padding:1px 5px;border-radius:4px;font-size:12px}
  .body pre{background:#21262d;padding:10px;border-radius:6px;overflow-x:auto;margin:8px 0}
  .body pre code{background:none;padding:0}
  .body ul,.body ol{padding-left:20px;margin:6px 0}
  .body a,.backlinks a{color:var(--accent);cursor:pointer;text-decoration:none}
  .body a:hover,.backlinks a:hover{text-decoration:underline}
  .backlinks{border-top:1px solid var(--line);margin-top:16px;padding-top:12px}
  .backlinks h3{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.1em;margin-bottom:6px}
  .backlinks li{list-style:none;margin:3px 0;font-size:13px}
  .empty{color:var(--muted);padding:40px 0;text-align:center}
</style></head>
<body><div id="app">
  <div id="left">
    <div id="topbar">
      <span class="title">__NAME__</span>
      <input id="search" placeholder="검색 (제목·id·태그)">
      <select id="typeFilter"><option value="">모든 타입</option></select>
      <span id="count" style="color:var(--muted);font-size:12px"></span>
    </div>
    <canvas id="cv"></canvas>
    <div class="legend" id="legend"></div>
  </div>
  <div id="right"><div class="empty">노드를 클릭하면 상세가 표시됩니다.</div></div>
</div>
<script>
const DATA = __DATA__;
const PALETTE = ["#2f81f7","#3fb950","#db61a2","#d29922","#a371f7","#f0883e","#56d4dd","#e34c4c","#8b949e"];
const types=[...new Set(DATA.nodes.map(n=>n.type))];
const typeColor={}; types.forEach((t,i)=>typeColor[t]=PALETTE[i%PALETTE.length]);
const byId={}; DATA.nodes.forEach(n=>byId[n.id]=n);
// backlinks
const backlinks={}; DATA.nodes.forEach(n=>backlinks[n.id]=[]);
DATA.edges.forEach(e=>{ if(backlinks[e.target]) backlinks[e.target].push(e.source); });
// adjacency for highlight
const adj={}; DATA.nodes.forEach(n=>adj[n.id]=new Set());
DATA.edges.forEach(e=>{adj[e.source]&&adj[e.source].add(e.target);adj[e.target]&&adj[e.target].add(e.source);});

const cv=document.getElementById("cv"),ctx=cv.getContext("2d");
let W,H,DPR=window.devicePixelRatio||1;
function resize(){const r=cv.parentElement.getBoundingClientRect();W=r.width;H=r.height;cv.width=W*DPR;cv.height=H*DPR;cv.style.width=W+"px";cv.style.height=H+"px";ctx.setTransform(DPR,0,0,DPR,0,0);}
window.addEventListener("resize",resize);resize();

// init positions on a circle
const N=DATA.nodes.length;
DATA.nodes.forEach((n,i)=>{const a=2*Math.PI*i/N;n.x=W/2+Math.cos(a)*Math.min(W,H)*0.3;n.y=H/2+Math.sin(a)*Math.min(W,H)*0.3;n.vx=0;n.vy=0;n.deg=adj[n.id].size;});
let selected=null, hover=null, dragging=null, query="", typeF="";

function visible(n){
  if(typeF && n.type!==typeF) return false;
  if(query){const q=query.toLowerCase();
    return n.title.toLowerCase().includes(q)||n.id.toLowerCase().includes(q)||(n.tags||[]).some(t=>t.toLowerCase().includes(q));}
  return true;
}

function tick(){
  // repulsion
  for(let i=0;i<N;i++){const a=DATA.nodes[i];
    for(let j=i+1;j<N;j++){const b=DATA.nodes[j];
      let dx=a.x-b.x,dy=a.y-b.y,d2=dx*dx+dy*dy||0.01,d=Math.sqrt(d2);
      let f=4200/d2; let fx=dx/d*f,fy=dy/d*f;
      a.vx+=fx;a.vy+=fy;b.vx-=fx;b.vy-=fy;}}
  // springs
  DATA.edges.forEach(e=>{const a=byId[e.source],b=byId[e.target];if(!a||!b)return;
    let dx=b.x-a.x,dy=b.y-a.y,d=Math.sqrt(dx*dx+dy*dy)||0.01,f=(d-110)*0.015;
    let fx=dx/d*f,fy=dy/d*f;a.vx+=fx;a.vy+=fy;b.vx-=fx;b.vy-=fy;});
  // centering + integrate
  DATA.nodes.forEach(n=>{n.vx+=(W/2-n.x)*0.0012;n.vy+=(H/2-n.y)*0.0012;
    if(n===dragging)return;
    n.vx*=0.86;n.vy*=0.86;n.x+=n.vx;n.y+=n.vy;
    n.x=Math.max(20,Math.min(W-20,n.x));n.y=Math.max(40,Math.min(H-20,n.y));});
}
function draw(){
  ctx.clearRect(0,0,W,H);
  const hl=selected||hover;
  // edges
  ctx.lineWidth=1;
  DATA.edges.forEach(e=>{const a=byId[e.source],b=byId[e.target];if(!a||!b)return;
    const dim = hl && !(hl===a||hl===b);
    const va=visible(a),vb=visible(b);
    ctx.strokeStyle=dim?"rgba(120,130,145,.07)":(va&&vb?"rgba(139,148,158,.35)":"rgba(139,148,158,.08)");
    ctx.beginPath();ctx.moveTo(a.x,a.y);
    // arrowhead
    let dx=b.x-a.x,dy=b.y-a.y,d=Math.sqrt(dx*dx+dy*dy)||1;
    let ex=b.x-dx/d*(7+Math.sqrt(b.deg)*1.5),ey=b.y-dy/d*(7+Math.sqrt(b.deg)*1.5);
    ctx.lineTo(ex,ey);ctx.stroke();});
  // nodes
  DATA.nodes.forEach(n=>{
    const r=5+Math.sqrt(n.deg)*1.6;
    const vis=visible(n);
    const dim=hl&&!(hl===n||adj[hl.id].has(n.id));
    ctx.globalAlpha=vis?(dim?0.25:1):0.12;
    ctx.beginPath();ctx.arc(n.x,n.y,r,0,7);
    ctx.fillStyle=typeColor[n.type]||"#888";ctx.fill();
    if(n===selected){ctx.lineWidth=2.5;ctx.strokeStyle="#fff";ctx.stroke();}
    // label
    if(vis&&(r>7||n===hl||hl===null&&query)){
      ctx.globalAlpha=vis?(dim?0.3:0.92):0.12;
      ctx.fillStyle="#e6edf3";ctx.font="11px -apple-system,sans-serif";ctx.textAlign="center";
      ctx.fillText(n.title.length>18?n.title.slice(0,17)+"…":n.title,n.x,n.y+r+12);}
  });
  ctx.globalAlpha=1;
}
function loop(){tick();draw();requestAnimationFrame(loop);}
loop();

function nodeAt(mx,my){let best=null,bd=1e9;
  DATA.nodes.forEach(n=>{const r=5+Math.sqrt(n.deg)*1.6+4;const d=(n.x-mx)**2+(n.y-my)**2;if(d<r*r&&d<bd){bd=d;best=n;}});return best;}
function rel(ev){const r=cv.getBoundingClientRect();return[ev.clientX-r.left,ev.clientY-r.top];}
cv.addEventListener("mousemove",e=>{const[x,y]=rel(e);if(dragging){dragging.x=x;dragging.y=y;dragging.vx=0;dragging.vy=0;return;}hover=nodeAt(x,y);cv.style.cursor=hover?"pointer":"default";});
cv.addEventListener("mousedown",e=>{const[x,y]=rel(e);const n=nodeAt(x,y);if(n){dragging=n;}});
window.addEventListener("mouseup",e=>{if(dragging){const[x,y]=rel(e);const n=nodeAt(x,y);if(n===dragging)select(n);}dragging=null;});

// ---- markdown (minimal) ----
function esc(s){return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}
function inline(s){
  s=esc(s);
  s=s.replace(/`([^`]+)`/g,(m,c)=>"<code>"+c+"</code>");
  s=s.replace(/\*\*([^*]+)\*\*/g,"<b>$1</b>");
  s=s.replace(/\[([^\]]+)\]\(([^)]+)\)/g,(m,t,h)=>{
    if(/\.md$/.test(h)){let id=h.startsWith("/")?h.slice(1,-3):h.replace(/^\.\//,"").slice(0,-3);
      return '<a data-nav="'+id+'">'+t+'</a>';}
    return '<a href="'+h+'" target="_blank" rel="noopener">'+t+'</a>';});
  return s;
}
function mdToHtml(md){
  const lines=md.split("\n");let out=[],i=0;
  while(i<lines.length){let l=lines[i];
    if(/^#{1,6}\s/.test(l)){const lv=l.match(/^#+/)[0].length;out.push("<h"+Math.min(lv,2)+">"+inline(l.replace(/^#+\s*/,""))+"</h"+Math.min(lv,2)+">");i++;continue;}
    if(/^```/.test(l)){let buf=[];i++;while(i<lines.length&&!/^```/.test(lines[i])){buf.push(esc(lines[i]));i++;}i++;out.push("<pre><code>"+buf.join("\n")+"</code></pre>");continue;}
    if(/^\s*\|.*\|/.test(l)){let buf=[];while(i<lines.length&&/^\s*\|.*\|/.test(lines[i])){buf.push(lines[i]);i++;}
      const rows=buf.filter(r=>!/^\s*\|[\s|:-]+\|\s*$/.test(r)).map(r=>r.trim().replace(/^\||\|$/g,"").split("|").map(c=>c.trim()));
      if(rows.length){let t="<table><tr>"+rows[0].map(c=>"<th>"+inline(c)+"</th>").join("")+"</tr>";
        for(let r=1;r<rows.length;r++)t+="<tr>"+rows[r].map(c=>"<td>"+inline(c)+"</td>").join("")+"</tr>";out.push(t+"</table>");}continue;}
    if(/^\s*[-*]\s/.test(l)){let buf=[];while(i<lines.length&&/^\s*[-*]\s/.test(lines[i])){buf.push("<li>"+inline(lines[i].replace(/^\s*[-*]\s/,""))+"</li>");i++;}out.push("<ul>"+buf.join("")+"</ul>");continue;}
    if(/^\s*\d+\.\s/.test(l)){let buf=[];while(i<lines.length&&/^\s*\d+\.\s/.test(lines[i])){buf.push("<li>"+inline(lines[i].replace(/^\s*\d+\.\s/,""))+"</li>");i++;}out.push("<ol>"+buf.join("")+"</ol>");continue;}
    if(l.trim()===""){i++;continue;}
    out.push("<p>"+inline(l)+"</p>");i++;}
  return out.join("\n");
}

function select(n){selected=n;render();}
function render(){
  const p=document.getElementById("right");
  if(!selected){p.innerHTML='<div class="empty">노드를 클릭하면 상세가 표시됩니다.</div>';return;}
  const n=selected;
  let html='<div class="kicker" style="color:'+(typeColor[n.type]||'#888')+'">'+esc(n.type)+'</div>';
  html+='<h1>'+esc(n.title)+'</h1>';
  if(n.description)html+='<div class="desc">'+esc(n.description)+'</div>';
  html+='<div class="meta">id: <code>'+esc(n.id)+'</code>';
  if(n.resource)html+=' · <a href="'+esc(n.resource)+'" target="_blank" rel="noopener">resource ↗</a>';
  html+='</div>';
  if(n.tags&&n.tags.length)html+='<div>'+n.tags.map(t=>'<span class="tag">'+esc(t)+'</span>').join("")+'</div>';
  html+='<div class="body">'+mdToHtml(n.body)+'</div>';
  const bl=backlinks[n.id]||[];
  if(bl.length){html+='<div class="backlinks"><h3>Cited by ('+bl.length+')</h3><ul>';
    bl.forEach(s=>{html+='<li><a data-nav="'+s+'">'+esc(byId[s]?byId[s].title:s)+'</a></li>';});
    html+='</ul></div>';}
  p.innerHTML=html;p.scrollTop=0;
  p.querySelectorAll("[data-nav]").forEach(a=>a.addEventListener("click",()=>{const t=byId[a.getAttribute("data-nav")];if(t)select(t);}));
}

// controls
const tf=document.getElementById("typeFilter");
types.forEach(t=>{const o=document.createElement("option");o.value=t;o.textContent=t;tf.appendChild(o);});
tf.addEventListener("change",e=>{typeF=e.target.value;updateCount();});
document.getElementById("search").addEventListener("input",e=>{query=e.target.value;updateCount();});
function updateCount(){const v=DATA.nodes.filter(visible).length;document.getElementById("count").textContent=v+" / "+N+" 노드, "+DATA.edges.length+" 링크";}
updateCount();
// legend
document.getElementById("legend").innerHTML=types.map(t=>'<span><span class="dot" style="background:'+typeColor[t]+'"></span>'+esc(t)+'</span>').join("");
</script></body></html>"""

out_html = HTML.replace("__DATA__", json.dumps(data, ensure_ascii=False)).replace("__NAME__", NAME)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(out_html)
print(f"wrote {OUT}")
print(f"nodes={len(nodes)} edges={len(uedges)} types={len(set(n['type'] for n in nodes))}")
