// Owned integration around the existing viewer. No CPU operations or network I/O.
function createViewrvSessionAdapter({graph,data,diagram,inspector,state,resources}) {
  const channel='viewrv-graph-v1',token=location.hash.slice(1);
  const roots=resources.bindings.blocks,representations=resources.bindings.representations||{};
  const cellFor=block=>representations[block]?.[0]||roots[block];
  const semantics=new Map(Object.keys(roots).map(block=>[cellFor(block),block]));
  const owned=new Map();
  for(const [id,owner] of Object.entries(data.owners)){
    if(!owned.has(owner))owned.set(owner,new Set([owner]));
    owned.get(owner).add(id);
  }
  let selected=null,focus=new Set(),observation=null,disposed=false,frame=0,pendingCentre=null;
  let theme={accent:'#4338ca',functional:'#b80078',active:'#e0ddff',functionalSoft:'#fff0f7'};
  const originalStyle=graph.getCellStyle,originalTooltip=graph.getTooltipForCell;
  const post=value=>parent.postMessage({channel,token,...value},'*');
  const ownerFor=cell=>data.owners[cell?.id]||cell?.id;
  function cells(blocks){
    return new Set([...blocks].flatMap(block=>[...(owned.get(cellFor(block))||[cellFor(block)])]));
  }
  function repaint(blocks){
    if(disposed)return;
    const view=graph.view,scale=view.scale,translate=view.translate;
    try{
      if(graph.useCssTransforms){view.scale=1;view.translate=new mxPoint(0,0);}
      for(const id of cells(blocks)){
        const cell=graph.model.getCell(id),render=cell&&view.getState(cell);
        if(!render?.shape)continue;
        const style=graph.getCellStyle(cell);
        if(!mxUtils.equalEntries(style,render.style)){render.style=style;graph.cellRenderer.redraw(render,false,true);}
      }
    }finally{view.scale=scale;view.translate=translate;}
  }
  graph.getCellStyle=function(cell,...args){
    const style=originalStyle.call(this,cell,...args),block=semantics.get(ownerFor(cell));
    if(!block||(!focus.has(block)&&selected!==block)||graph.model.isEdge(cell))return style;
    // Ownership includes text labels. Only outlined circuit shapes receive a
    // colored frame; highlighting a module must not turn its labels into boxes.
    const base=diagram.savedStyle(cell.id)||style;
    if(base.shape==='text'||!base.strokeColor||base.strokeColor==='none')return {...style,opacity:100,textOpacity:100};
    const selection=selected===block;
    return {...style,opacity:100,textOpacity:100,strokeColor:selection?theme.accent:theme.functional,
      strokeWidth:selection?4:3,fillColor:selection?theme.active:theme.functionalSoft};
  };
  graph.getTooltipForCell=function(cell){
    const original=originalTooltip.call(this,cell),block=semantics.get(ownerFor(cell));
    if(!block)return original;
    const note=document.createElement('p');note.style.marginTop='6px';
    note.textContent=observation?.observation?.snapshot?
      `${observation.stale?'Último estado recibido':'Captura recibida'} · ciclo ${observation.observation.snapshot.cycle_count}. Los valores disponibles se consultan en el inspector.`:
      'Sin captura recibida. La explicación es conceptual; no se presumen valores.';
    return (original||'')+note.outerHTML;
  };
  function selectComponent(block,{centre=false,notify=false}={}){
    if(!Object.hasOwn(roots,block))return;
    const previous=selected;selected=block;
    // Native selectModule already replaces the inspection and diffs its cells.
    // Clearing first would repaint the complete graph twice. A native selection
    // echoed by the parent also retains its field inspection.
    const native=state.selectedModule||data.fields[state.selectedField]?.owner;
    if(previous!==block||native!==cellFor(block)||state.selectedConnection)inspector.selectModule(cellFor(block));
    repaint(new Set([...focus,previous,selected].filter(Boolean)));
    if(centre)centreOn(block);
    if(notify)post({kind:'select',block_id:block});
  }
  function centreOn(block){
    if(!graph.container.clientWidth||!graph.container.clientHeight){pendingCentre=block;return;}
    const render=graph.view.getState(graph.model.getCell(cellFor(block)));
    if(!render)return;
    const scale=graph.useCssTransforms?1:graph.view.scale,translate=graph.useCssTransforms?{x:0,y:0}:graph.view.translate;
    const camera=diagram.camera.cameraCentre();
    diagram.camera.resizeDiagram({...camera,x:(render.x+render.width/2)/scale-translate.x,y:(render.y+render.height/2)/scale-translate.y});
  }
  function setFocus(blocks){
    const previous=focus;focus=new Set(blocks.filter(block=>Object.hasOwn(roots,block)));
    repaint(new Set([...previous,...focus,selected].filter(Boolean)));
  }
  function setObservation(context){
    if(observation&&['session_id','program_id','source_version'].some(key=>observation[key]!==context[key]))throw Error('La observación cambió de sesión o revisión.');
    observation=context;graph.tooltipHandler.hide();
    setFocus((context.observation?.interpretation?.cycle_activity||[]).flatMap(row=>row.blocks));
    post({kind:'observed',step_index:context.observation?.step_index??null,cycle_count:context.observation?.snapshot?.cycle_count??null});
  }
  const mouse={mouseDown(){},mouseMove(){},mouseUp(){
    cancelAnimationFrame(frame);frame=requestAnimationFrame(()=>{
      const native=state.selectedModule||data.fields[state.selectedField]?.owner;
      const block=semantics.get(native);
      if(state.selectedConnection){
        const previous=selected;selected=null;repaint(new Set([...focus,previous].filter(Boolean)));
        const text=id=>document.getElementById(id)?.textContent||'';
        post({kind:'connection',connection:{id:state.selectedConnection,name:text('connection-title'),route:text('connection-route'),description:[text('connection-introduction'),...Array.from(document.querySelectorAll('#connection-description p')).map(node=>node.textContent)].join('\n')}});
      }else if(block&&block!==selected){const previous=selected;selected=block;repaint(new Set([...focus,previous,block].filter(Boolean)));post({kind:'select',block_id:block});}
    });
  }};
  graph.addMouseListener(mouse);
  function resize(){if(!disposed&&graph.container.clientWidth&&graph.container.clientHeight){diagram.camera.resize();if(pendingCentre){const block=pendingCentre;pendingCentre=null;centreOn(block);}}}
  function activate(){post({kind:'activate'});}
  function onMessage(event){
    const value=event.data;
    if(disposed||event.source!==parent||value?.channel!==channel||value.token!==token)return;
    try{
      if(value.kind==='observation')setObservation(value.context);
      else if(value.kind==='select')selectComponent(value.block_id,{centre:!!value.centre});
      else if(value.kind==='focus')setFocus(value.blocks);
      else if(value.kind==='resize')resize();
      else if(value.kind==='theme'){theme=value.theme;document.documentElement.style.setProperty('--viewrv-selection',theme.accent);repaint(new Set([...focus,selected].filter(Boolean)));}
      else if(value.kind==='dispose')dispose();
    }catch(error){post({kind:'error',message:String(error.message)});}
  }
  function dispose(){
    if(disposed)return;disposed=true;cancelAnimationFrame(frame);
    window.removeEventListener('message',onMessage);window.removeEventListener('pagehide',dispose);
    window.removeEventListener('focus',activate);document.removeEventListener('pointerdown',activate,true);
    graph.removeMouseListener(mouse);graph.getCellStyle=originalStyle;graph.getTooltipForCell=originalTooltip;
    graph.tooltipHandler.hide();graph.destroy();
  }
  window.addEventListener('message',onMessage);window.addEventListener('pagehide',dispose,{once:true});
  window.addEventListener('focus',activate);document.addEventListener('pointerdown',activate,true);
  post({kind:'ready',profile:resources.profile,diagram_sha256:resources.diagram_sha256,bindings_sha256:resources.bindings_sha256,education_sha256:resources.education_sha256});
  return {setObservation,selectComponent,setFocus,resize,dispose};
}
