import { GridStack } from 'gridstack'
import 'gridstack/dist/gridstack.css'

const gridEl = document.querySelector('.grid-stack')

if (gridEl) {
    let grid = GridStack.init({
        cellHeight: 80,
        columnOpts: {
            breakpointForWindow: true,
            breakpoints: [{ w: 700, c: 1 }, { w: 850, c: 2 }, { w: 950, c: 2 }, { w: 1100, c: 2 }]
        },
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

    var isLocked = true;
    const lockButton = document.getElementById('lock-button');
    if (lockButton) {
        lockButton.addEventListener('click', () => {
            isLocked = !isLocked;
            grid.setStatic(isLocked);
            const lockSvg = document.getElementById('lock-svg');
            if (lockSvg) lockSvg.style.fill = isLocked ? "#605dff" : "#ff6700";
        });
    }
}
