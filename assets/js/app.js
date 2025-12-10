// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

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
            content.innerText = 'Tripwire Settings';

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




import * as echarts from 'echarts';
import $ from "jquery";

document.addEventListener('DOMContentLoaded', () => {
    var chartDom = document.getElementById('map');
    var systemChart = echarts.init(chartDom);
    var option;

    systemChart.showLoading();
    $.get('/data.json', function (data) {
        systemChart.hideLoading();
        systemChart.setOption(
            (option = {
                tooltip: {
                    trigger: 'item',
                    triggerOn: 'mousemove'
                },
                series: [
                    {
                        type: 'tree',
                        data: [data],
                        orient: 'vertical',
                        expandAndCollapse: true,
                        initialTreeDepth: 999,
                        animationDurationUpdate: 100,
                        label: {
                            show: true,
                            formatter: '{a} \n{b} \n{c}'
                        },

                        left: '-50%',
                        right: '-50%',
                        top: '10%',
                        bottom: '20%',

                        symbol: 'roundRect',
                        symbolSize: [140, 80],

                        roam: 'true', // div needs lock    
                        edgeShape: 'polyline',
                        //   lineStyle: {curveness: .5}
                    }
                ],
            })
        );
    });

    option && systemChart.setOption(option);


    var chartDom = document.getElementById('system-chart');
    var treeMap = echarts.init(chartDom);
    var option;

    option = {
        title: {
            text: 'System'
        },
        animationDurationUpdate: 100,

        tooltip: {
            trigger: 'axis',
            axisPointer: {
                type: 'cross',
                label: {
                    backgroundColor: '#6a7985'
                }
            }
        },
        legend: {
            data: ['Ships Destoryed', 'Pods Destroyed', 'NPCs Destroyed', 'Jumps',]
        },
        xAxis: [
            {
                type: 'category',
                boundaryGap: false,
                data: ['00:00', '00:00', '00:00', '00:00', '00:00', '00:00', '00:00']
            }
        ],
        yAxis: [
            {
                type: 'value'
            }
        ],
        series: [
            {
                name: 'Ships Destoryed',
                type: 'line',
                stack: 'Total',
                areaStyle: {},
                emphasis: {
                    focus: 'series'
                },
                data: [120, 132, 101, 134, 90, 230, 210]
            },
            {
                name: 'Pods Destroyed',
                type: 'line',
                stack: 'Total',
                areaStyle: {},
                emphasis: {
                    focus: 'series'
                },
                data: [220, 182, 191, 234, 290, 330, 310]
            },
            {
                name: 'Jumps',
                type: 'line',
                stack: 'Total',
                areaStyle: {},
                emphasis: {
                    focus: 'series'
                },
                data: [150, 232, 201, 154, 190, 330, 410]
            },
            {
                name: 'NPCs Destroyed',
                type: 'line',
                stack: 'Total',
                areaStyle: {},
                emphasis: {
                    focus: 'series'
                },
                data: [320, 332, 301, 334, 390, 330, 320]
            },
        ]
    };

    option && treeMap.setOption(option);

});












import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/tripwire"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: { ...colocatedHooks },
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket
if (process.env.NODE_ENV === "development") {
    window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
        reloader.enableServerLogs()

        let keyDown
        window.addEventListener("keydown", e => keyDown = e.key)
        window.addEventListener("keyup", _e => keyDown = null)
        window.addEventListener("click", e => {
            if (keyDown === "c") {
                e.preventDefault()
                e.stopImmediatePropagation()
                reloader.openEditorAtCaller(e.target)
            } else if (keyDown === "d") {
                e.preventDefault()
                e.stopImmediatePropagation()
                reloader.openEditorAtDef(e.target)
            }
        }, true)

        window.liveReloader = reloader
    })
}

