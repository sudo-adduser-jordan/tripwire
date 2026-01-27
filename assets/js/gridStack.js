import { GridStack } from 'gridstack'
import 'gridstack/dist/gridstack.css'


let grid = GridStack.init({
    cellHeight: 80,
    // animate: true, // show immediate (animate: true is nice for user dragging though)
    columnOpts: {
        breakpointForWindow: true,  // test window vs grid size
        breakpoints: [{ w: 700, c: 1 }, { w: 850, c: 2 }, { w: 950, c: 2 }, { w: 1100, c: 2 }]
    },
    // float: true,
    staticGrid: true,
})
.on('change', (ev, gsItems) => { });
// Store previous column count
let previousColumn = grid.getColumn();

// Define explicit orders for each breakpoint
const ordersMap = {
  1: [0, 1, 2],
  3: [0, 2, 1],
  6: [2, 0, 1],
  8: [1, 2, 0]
};

grid.on('change', (ev, gsItems) => {
  const currentColumn = grid.getColumn();

  if (currentColumn !== previousColumn) {
    previousColumn = currentColumn;

    // Determine order based on current column
    const order = ordersMap[currentColumn] || [];

    // Reorder widgets explicitly
    order.forEach((widgetIndex, position) => {
      const item = gsItems[widgetIndex];
      if (item) {
        grid.update(item.el, {
          x: position % currentColumn,
          y: Math.floor(position / currentColumn)
        });
      }
    });
  }
});

document.getElementById("settings-button").addEventListener('click', toggleSettingsWidget);

var isLocked = true;
document.getElementById('lock-button').addEventListener('click', () => {
    isLocked = !isLocked;
    grid.setStatic(isLocked);
    document.getElementById('lock-svg').style.fill = isLocked ? "#605dff" : "#ff6700";
    // document.getElementById('lock-svg').style.fill = isLocked ? "#ff6700" : "#605dff";
});

function toggleSettingsWidget() {

    if (!grid) {
        console.error("GridStack not initialized yet");
        return;
    }

    const button = document.getElementById("settings-button");
    var settingsWidget = document.getElementById("settings-widget")

    if (settingsWidget) {
        button.innerHTML = `Settings<span aria-hidden="true"s> &rarr; </span>`
        grid.removeWidget(settingsWidget);
    }

    if (!settingsWidget) {
        button.innerHTML = `Close<span aria-hidden="true"s> &larr; </span>`

        const item = document.createElement('div');
        item.id = 'settings-widget'
        item.classList.add('grid-stack-item');
        item.setAttribute('tabindex', "0");

        const content = document.createElement('div');
        content.classList.add('grid-stack-item-content');


        const clone = document.getElementById('settings-template').cloneNode(true);
        clone.classList.remove('hidden')

        item.appendChild(content);
        content.appendChild(clone)

        grid.makeWidget(item, {
            w: 12,
            h: 9,
            x: 0,
            y: 0
        });

        // item.focus() // dev // make useable in prod
    }
}

