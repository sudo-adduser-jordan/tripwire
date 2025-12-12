import { GridStack } from 'gridstack'
import 'gridstack/dist/gridstack.css'

// const options = {
//     // float: true,
//     // staticGrid: true,
// }

var isLocked = false;
window.grid = null;
document.addEventListener("DOMContentLoaded", () => {
    window.grid = GridStack.init({/* options */}, '.grid-stack');

    const lockButton = document.getElementById('lock-toggle');
    lockButton.addEventListener('click', () => {
        const svg = document.getElementById('lockImage');
        isLocked = !isLocked;
        grid.setStatic(isLocked);
        svg.style.fill = isLocked ? "#605dff" : "#ff6700";
    });
});

