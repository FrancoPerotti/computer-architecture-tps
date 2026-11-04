// Recompute viewing rectangles from the native renderer after XML layout edits.
// This only changes camera metadata; it never writes cell geometry or topology.
function refreshViewrvCameras(graph,data){
  const scale=graph.view.scale,translate=graph.view.translate;
  const world=box=>graph.useCssTransforms?{x:box.x,y:box.y,width:box.width,height:box.height}:{x:box.x/scale-translate.x,y:box.y/scale-translate.y,width:box.width/scale,height:box.height/scale};
  const full=world(graph.view.graphBounds);
  for(const page of data.pages){
    const cells=new Set([...(page.components||[]),...(page.highlight||[]),...(page.support||[])]);
    const boxes=[...cells].map(id=>graph.view.getState(graph.model.getCell(id))).filter(Boolean).map(render=>world(render.boundingBox||render));
    const bounds=page.id===data.presentation.overview.id||!boxes.length?full:{x:Math.min(...boxes.map(box=>box.x)),y:Math.min(...boxes.map(box=>box.y)),width:0,height:0};
    if(bounds!==full){bounds.width=Math.max(...boxes.map(box=>box.x+box.width))-bounds.x;bounds.height=Math.max(...boxes.map(box=>box.y+box.height))-bounds.y;}
    if(![bounds.x,bounds.y,bounds.width,bounds.height].every(Number.isFinite))throw Error('No se pudo encuadrar el dibujo actual.');
    page.camera={...page.camera,...bounds,width:Math.max(1,bounds.width),height:Math.max(1,bounds.height)};
  }
}

// The read-only CSS-transformed viewer keeps native cell states in world units.
// A viewport change needs the native transform/size/events, not a 1,700-cell
// validation pass. Initial drawing and any model changes still use native validation.
function installViewrvViewport(graph){
  const view=graph.view,native=view.scaleAndTranslate;
  if(!graph.useCssTransforms||view.viewrvFastViewport)return;
  const svg=view.getDrawPane()?.ownerSVGElement;
  if(!svg)return;
  // Keep the SVG viewport tied to the visible container. Native zoom changes
  // its minimum size, which otherwise relays out every HTML label. A separate
  // non-interactive spacer preserves the exact native scrollable extent.
  const spacer=document.createElement('div');spacer.setAttribute('aria-hidden','true');
  spacer.style.cssText='position:absolute;left:0;top:0;pointer-events:none';
  svg.parentNode.insertBefore(spacer,svg);
  const nativeSize=graph.sizeDidChange;
  graph.sizeDidChange=function(){
    const result=nativeSize.apply(this,arguments);
    if(this.useCssTransforms){
      spacer.style.width=svg.style.minWidth;spacer.style.height=svg.style.minHeight;
      svg.style.minWidth='0px';svg.style.minHeight='0px';
      svg.style.position='absolute';svg.style.left='0';svg.style.top='0';svg.style.overflow='visible';
    }
    return result;
  };
  const nativeTransform=graph.updateCssTransform;
  graph.updateCssTransform=function(){
    if(!this.useCssTransforms)return nativeTransform.apply(this,arguments);
    const pane=this.view.getDrawPane()?.parentNode;if(!pane)return;
    const previous=pane.getAttribute('transform');pane.setAttribute('transformOrigin','0 0');
    if(this.armTransformTransition)this.armTransformTransition=false;
    else if(pane.style.transition)pane.style.transition='';
    const scale=Math.round(this.currentScale*1000000)/1000000,x=Math.round(this.currentTranslate.x*100)/100,y=Math.round(this.currentTranslate.y*100)/100;
    const transform=`scale(${scale},${scale})translate(${x},${y})`;pane.setAttribute('transform',transform);
    if(previous!==transform)this.fireEvent(new mxEventObject('cssTransformChanged'),'transform',transform);
  };
  view.scaleAndTranslate=function(scale,x,y){
    if(!graph.useCssTransforms)return native.apply(this,arguments);
    const previousScale=this.scale,previousTranslate=new mxPoint(this.translate.x,this.translate.y);
    this.scale=scale;this.translate.x=x;this.translate.y=y;
    graph.currentScale=scale;graph.currentTranslate.x=x;graph.currentTranslate.y=y;
    graph.updateCssTransform();graph.sizeDidChange();
    this.fireEvent(new mxEventObject(mxEvent.SCALE_AND_TRANSLATE,'scale',scale,'previousScale',previousScale,'translate',this.translate,'previousTranslate',previousTranslate));
  };
  view.viewrvStrokeNodes=new Set();
  const collect=node=>{
    if(!node)return;
    for(const element of [node,...node.querySelectorAll('[style]')]){
      if(element.style.strokeWidth.includes('--inspection-stroke')||element.style.strokeWidth.includes('--module-stroke')||element.style.strokeDasharray.includes('--diagram-scale')){
        view.viewrvStrokeNodes.add(element);setViewrvStrokeScale(element,view.scale);
      }
    }
  };
  const redraw=graph.cellRenderer.redraw;
  graph.cellRenderer.redraw=function(render){const result=redraw.apply(this,arguments);collect(render.shape?.node);return result;};
  collect(view.getDrawPane());
  view.viewrvFastViewport=true;
}

// Scope stroke variables to their SVG paths. Changing inherited variables on
// the canvas forces style recalculation through every foreignObject and label.
function updateViewrvStrokes(graph,scale){
  for(const node of graph.view.viewrvStrokeNodes||[]){
    if(!node.isConnected){graph.view.viewrvStrokeNodes.delete(node);continue;}
    setViewrvStrokeScale(node,scale);
  }
}

function setViewrvStrokeScale(node,scale){
  node.style.setProperty('--inspection-stroke',Math.max(.75,Math.min(3,3*scale))+'px');
  node.style.setProperty('--module-stroke',Math.max(1,Math.min(4,4*scale))+'px');
  node.style.setProperty('--diagram-scale',scale);
}
