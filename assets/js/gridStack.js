
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
            
            
               <input type="checkbox" checked="checked" class="checkbox checkbox-primary" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-secondary" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-accent" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-neutral" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-info" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-success" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-warning" />
    <input type="checkbox" checked="checked" class="checkbox checkbox-error" />

    <input type="checkbox" checked="checked" class="toggle toggle-primary" />
    <input type="checkbox" checked="checked" class="toggle toggle-secondary" />
    <input type="checkbox" checked="checked" class="toggle toggle-accent" />
    <input type="checkbox" checked="checked" class="toggle toggle-neutral" />
    <input type="checkbox" checked="checked" class="toggle toggle-info" />
    <input type="checkbox" checked="checked" class="toggle toggle-success" />
    <input type="checkbox" checked="checked" class="toggle toggle-warning" />
    <input type="checkbox" checked="checked" class="toggle toggle-error" />


    <input type="range" min="0" max="100" value="40" class="range range-primary" />
    <input type="range" min="0" max="100" value="40" class="range range-secondary" />
    <input type="range" min="0" max="100" value="40" class="range range-accent" />
    <input type="range" min="0" max="100" value="40" class="range range-success" />
    <input type="range" min="0" max="100" value="40" class="range range-warning" />
    <input type="range" min="0" max="100" value="40" class="range range-info" />
    <input type="range" min="0" max="100" value="40" class="range range-error" />


    <input
    type="radio" name="radio-12" checked="checked"
    class="radio bg-red-100 border-red-300 checked:bg-red-200 checked:text-red-600 checked:border-red-600" />
    <input
    type="radio" name="radio-12" checked="checked"
    class="radio bg-blue-100 border-blue-300 checked:bg-blue-200 checked:text-blue-600 checked:border-blue-600" />



    <select class="select select-ghost">
      <option disabled selected>Pick a font</option>
      <option>Inter</option>
      <option>Poppins</option>
      <option>Raleway</option>
    </select>

<div class="tabs tabs-box">
  <input type="radio" name="my_tabs_6" class="tab" aria-label="Tab 1" />
  <div class="tab-content bg-base-100 border-base-300 p-6">Tab content 1</div>

  <input type="radio" name="my_tabs_6" class="tab" aria-label="Tab 2" checked="checked" />
  <div class="tab-content bg-base-100 border-base-300 p-6">Tab content 2</div>

  <input type="radio" name="my_tabs_6" class="tab" aria-label="Tab 3" />
  <div class="tab-content bg-base-100 border-base-300 p-6">Tab content 3</div>
</div>

  <!-- Open the modal using ID.showModal() method -->
  <button class="btn" onclick="my_modal_2.showModal()">open modal</button>
  <dialog id="my_modal_2" class="modal">
    <div class="modal-box">
      <h3 class="text-lg font-bold">Hello!</h3>
      <p class="py-4">Press ESC key or click outside to close</p>
    </div>
    <form method="dialog" class="modal-backdrop">
      <button>close</button>
    </form>
  </dialog>

            
            
            
            
            
            
            
            
            
            
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
