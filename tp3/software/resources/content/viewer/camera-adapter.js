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

// The native viewer defers graph creation at zero width. Its caller needs the
// graph immediately, so wait for the tab to be shown before creating it.
function waitForViewrvCanvas() {
  const canvas = document.getElementById('diagram');
  if (canvas.clientWidth && canvas.clientHeight) return;
  return new Promise(resolve => {
    const observer = new ResizeObserver(() => {
      if (!canvas.clientWidth || !canvas.clientHeight) return;
      observer.disconnect();
      resolve();
    });
    observer.observe(canvas);
  });
}

function installViewrvWheelZoom(graph, zoomAt) {
  let frame = null, zoomDelta = 0, position;

  function queueZoom(deltaY, deltaMode, x, y, sensitivity) {
    const delta = deltaY * (deltaMode === 1 ? 16 : deltaMode === 2 ? innerHeight : 1);
    if (!delta || ![delta, x, y].every(Number.isFinite)) return;
    zoomDelta -= Math.max(-300, Math.min(300, delta)) * sensitivity;
    position = { x, y };
    if (frame !== null) return;
    frame = requestAnimationFrame(() => {
      frame = null;
      const factor = Math.exp(zoomDelta);
      zoomDelta = 0;
      zoomAt(graph.view.scale * factor, position.x, position.y);
    });
  }

  document.getElementById('canvas-area').addEventListener('wheel', event => {
    if (!(event.ctrlKey || event.metaKey)) return;
    if (event.cancelable) event.preventDefault();
    event.stopImmediatePropagation();
    queueZoom(event.deltaY, event.deltaMode, event.clientX, event.clientY, .002);
  }, { passive: false, capture: true });

  window.addEventListener('message', event => {
    const value = event.data;
    if (event.source !== parent || parent === window || value?.channel !== 'viewrv-camera-v1') return;
    // Chromium encodes touchpad pinch as deltaY = -100 × log(scale).
    queueZoom(value.deltaY, value.deltaMode, value.x, value.y, .01);
  });
}

// Tap still selects native cells. A drag or a second contact takes over the camera.
function installViewrvTouchCamera(graph, zoomAt) {
  const canvas = graph.container;
  const contacts = new Map();
  const capture = { capture: true, passive: false };
  let mode = null, suppressClick = false, last = null, frame = null;
  graph.panningHandler.setPinchEnabled(false);

  function measure() {
    const [a, b] = contacts.values();
    if (!b) return { x: a.clientX, y: a.clientY };
    return {
      distance: Math.max(1, Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY)),
      x: (a.clientX + b.clientX) / 2,
      y: (a.clientY + b.clientY) / 2,
    };
  }
  function apply() {
    frame = null;
    if (!last) return;
    const next = measure();
    canvas.scrollLeft += last.x - next.x;
    canvas.scrollTop += last.y - next.y;
    if (mode === 'pinch' && next.distance !== last.distance)
      zoomAt(graph.view.scale * next.distance / last.distance, next.x, next.y);
    last = next;
  }
  function flush() {
    if (frame === null) return;
    cancelAnimationFrame(frame);
    apply();
  }
  function consume(event) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
  function takeOver() {
    suppressClick = true;
    graph.panningHandler.reset();
    graph.currentPointerId = null;
    graph.tapAndHoldValid = graph.tapAndHoldInProgress = false;
    graph.lastTouchTime = 0;
    graph.tooltipHandler.hide();
  }

  canvas.addEventListener('pointerdown', event => {
    if (!mode) suppressClick = false;
    if (event.pointerType !== 'touch') return;
    flush();
    contacts.set(event.pointerId, event);
    if (contacts.size === 2) {
      if (!mode) takeOver();
      mode = 'pinch';
    }
    last = contacts.size <= 2 ? measure() : null;
    if (mode) consume(event);
  }, capture);
  canvas.addEventListener('pointermove', event => {
    if (event.pointerType !== 'touch' || !contacts.has(event.pointerId)) return;
    contacts.set(event.pointerId, event);
    if (!mode) {
      const next = measure();
      if (Math.hypot(next.x - last.x, next.y - last.y) < 5) return;
      takeOver();
      mode = 'pan';
    }
    consume(event);
    if (last && frame === null) frame = requestAnimationFrame(apply);
  }, capture);
  function release(event) {
    if (event.pointerType !== 'touch' || !contacts.has(event.pointerId)) return;
    flush();
    contacts.delete(event.pointerId);
    if (mode) consume(event);
    // After a pinch, a remaining finger stays inactive until lifted.
    last = contacts.size === 2 ? measure() : null;
    if (!contacts.size) mode = null;
  }
  canvas.addEventListener('pointerup', release, capture);
  canvas.addEventListener('pointercancel', release, capture);
  canvas.addEventListener('click', event => {
    if (suppressClick && event.pointerType === 'touch') consume(event);
  }, capture);
}
