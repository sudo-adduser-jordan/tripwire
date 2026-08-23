import * as echarts from 'echarts'

let treeMap = null
let loaded = false

function renderTreeMap(data) {
    const options = {
        tooltip: {
            trigger: 'item',
            triggerOn: 'mousemove',
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
                    formatter: '{b} \n{c}',
                },
                left: '-25%',
                right: '-25%',
                top: '10%',
                bottom: '20%',
                symbol: 'roundRect',
                symbolSize: [100, 60],
                roam: 'move',
                edgeShape: 'polyline',
            },
        ],
    }

    treeMap.setOption(options)
}

function initTreeMap() {
    const dom = document.getElementById('treeMap')
    if (!dom || treeMap) return

    treeMap = echarts.init(dom)

    new ResizeObserver(() => {
        if (treeMap) treeMap.resize()
    }).observe(dom)

    if (!loaded) {
        loaded = true
        fetch('/data.json')
            .then((response) => response.json())
            .then(renderTreeMap)
            .catch(() => {})
    }
}

document.addEventListener('DOMContentLoaded', initTreeMap)

window.TripwireCharts = window.TripwireCharts || {}
window.TripwireCharts.initTreeMap = initTreeMap
