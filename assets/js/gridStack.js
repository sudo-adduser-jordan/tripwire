import { GridStack } from 'gridstack'
import 'gridstack/dist/gridstack.css'

// const options = {
//     // float: true,
//     // staticGrid: true,
// }
function applyGridSizeForWidth(grid, el) {
  const w = window.innerWidth; // current viewport width


  if (w < 768) {
    // mobile
    switch (el.id) {
      case "system-container":
        grid.update(el, {x: 0, y: 0, w: 12, h: 6 });
        break;

      case "notes-container":
        grid.update(el, {x: 0, y: 6, w: 12, h: 6 });
        break;

      case "signatures-container":
        grid.update(el, {x: 0, y: 12, w: 12, h: 6 });
        break;

      case "map-container":
        grid.update(el, {x: 0, y: 69,  w: 12, h: 12 });
        break;
    }
  } else if (w < 1024) {
    // tablet
    switch (el.id) {
      case "system-container":
        grid.update(el, {x: 0, y: 0, w: 6, h: 3 });
        break;

      case "notes-container":
        grid.update(el, {x: 6, y: 0, w: 6, h: 3 });
        break;

      case "signatures-container":
        grid.update(el, {x: 0, y: 4, w: 12, h: 3 })    ;
        break;

      case "map-container":
        grid.update(el, {x: 0, y: 12, w: 12, h: 6 });
        break;
    }
  } else {
    // desktop
    switch (el.id) {
      case "system-container":
        grid.update(el, {x: 0, y: 0, w: 6, h: 3 });
        break;

      case "notes-container":
        grid.update(el, {x: 6, y: 0, w: 6, h: 3 });
        break;

      case "signatures-container":
        grid.update(el, {x: 0, y: 4, w: 12, h: 3 })    ;
        break;

      case "map-container":
        grid.update(el, {x: 0, y: 12, w: 12, h: 6 });
        break;
    }
  }
}

var isLocked = false;
window.grid = null;
document.addEventListener("DOMContentLoaded", () => {

const grid = GridStack.init();           

const system   = document.getElementById('system-container');
const signatures   = document.getElementById('signatures-container');
const notes   = document.getElementById('notes-container');
const map   = document.getElementById('map-container');

applyGridSizeForWidth(grid, system);     
applyGridSizeForWidth(grid, signatures);       
applyGridSizeForWidth(grid, notes);       
applyGridSizeForWidth(grid, map);       

window.addEventListener('resize', () => {
  applyGridSizeForWidth(grid, system);       
  applyGridSizeForWidth(grid, signatures);       
  applyGridSizeForWidth(grid, notes);       
  applyGridSizeForWidth(grid, map);       
});


    window.grid = GridStack.init({/* options */}, '.grid-stack');

    const lockButton = document.getElementById('lock-toggle');
    lockButton.addEventListener('click', () => {
        const svg = document.getElementById('lockImage');
        isLocked = !isLocked;
        grid.setStatic(isLocked);
        svg.style.fill = isLocked ? "#605dff" : "#ff6700";
    });
});

