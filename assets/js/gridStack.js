
import { GridStack } from 'gridstack'
import 'gridstack/dist/gridstack.css'

const options = {
    // float: true,
    // staticGrid: true,
}

let grid;
let isLocked = false;

document.addEventListener('DOMContentLoaded', () => {
    grid = GridStack.init();

    const lockButton = document.getElementById('lock-toggle');
    lockButton.addEventListener('click', () => {
        const svg = document.getElementById('lockImage');
        isLocked = !isLocked;
        grid.setStatic(isLocked);
        svg.style.fill = isLocked ? "#605dff" : "#ff6700";
    });

    var isOpen = false;
    const settingsButton = document.getElementById('settings-toggle');
    settingsButton.addEventListener('click', () => {
        if (isOpen) {
            isOpen = false
            const button = document.getElementById("settings-toggle");
            button.innerHTML = `Settings<span aria-hidden="true"s> &rarr; </span>`
            var widgetEl = document.getElementById('grid-stack-settings'); // or specific selector
            grid.removeWidget(widgetEl);

        } else {
            isOpen = true
            const button = document.getElementById("settings-toggle");
            button.innerHTML = `Close<span aria-hidden="true"s> &larr; </span>`

            const widget = document.createElement('div');
            widget.classList.add('grid-stack-item');
            widget.id = 'grid-stack-settings'

            const content = document.createElement('div');
            content.classList.add('grid-stack-item-content');
            content.innerHTML = `
            
            Tripwire Settings
                <input type="checkbox" checked="checked" class="checkbox checkbox-primary" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-secondary" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-accent" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-neutral" />

    <input type="checkbox" checked="checked" class="checkbox checkbox-info" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-success" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-warning" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-error" />

            `

            widget.appendChild(content);

            grid.makeWidget(widget, {
                w: 12,
                h: 4,
                x: 0,
                y: 0
            });

        }
    });
});
