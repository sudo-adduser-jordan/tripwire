import * as echarts from 'echarts'

let stackedChart = null
let stackedChartEl = null
let stackedChartObserver = null
let stackedChartTries = 0

const stackedChartOptions = {
    animationDurationUpdate: 100,
    grid: {
        top: '10%',
        bottom: '20%',
        left: '7%',
        right: '7%',
        containLabel: false,
    },
    tooltip: {
        trigger: 'axis',
        axisPointer: {
            type: 'cross',
            label: {
                backgroundColor: '#6a7985',
            },
        },
    },
    legend: {
        data: ['Ships Destoryed', 'Pods Destroyed', 'NPCs Destroyed', 'Jumps'],
    },
    xAxis: [
        {
            type: 'category',
            boundaryGap: false,
            data: ['00:00', '00:00', '00:00', '00:00', '00:00', '00:00', '00:00'],
        },
    ],
    yAxis: [
        {
            type: 'value',
        },
    ],
    series: [
        {
            name: 'Ships Destoryed',
            type: 'line',
            stack: 'Total',
            areaStyle: {},
            emphasis: {
                focus: 'series',
            },
            data: [0, 0, 1, 6, 0, 0, 1],
        },
        {
            name: 'Pods Destroyed',
            type: 'line',
            stack: 'Total',
            areaStyle: {},
            emphasis: {
                focus: 'series',
            },
            data: [0, 0, 0, 5, 0, 0, 1],
        },
        {
            name: 'Jumps',
            type: 'line',
            stack: 'Total',
            areaStyle: {},
            emphasis: {
                focus: 'series',
            },
            data: [10, 15, 12, 50, 5, 1, 15],
        },
        {
            name: 'NPCs Destroyed',
            type: 'line',
            stack: 'Total',
            areaStyle: {},
            emphasis: {
                focus: 'series',
            },
            data: [150, 200, 100, 165, 250, 96, 153],
        },
    ],
}

function initSystemChart() {
    const dom = document.getElementById('system-chart')
    if (!dom) return

    // LiveView may replace the node across patches; drop a stale instance.
    if (stackedChart && stackedChartEl && stackedChartEl !== dom) {
        stackedChart.dispose()
        stackedChart = null
        stackedChartEl = null
    }

    // echarts renders nothing (grid top included) when initialized in a
    // zero-size container, which is exactly the state on first load before
    // GridStack reveals the grid. Wait for layout instead of init-once.
    if (dom.clientWidth === 0 || dom.clientHeight === 0) {
        if (stackedChartTries < 60) {
            stackedChartTries += 1
            requestAnimationFrame(() => initSystemChart())
        }
        return
    }
    stackedChartTries = 0

    if (!stackedChart) {
        stackedChart = echarts.init(dom)
        stackedChartEl = dom
        stackedChart.setOption(stackedChartOptions)

        stackedChartObserver = new ResizeObserver(() => {
            if (stackedChart) stackedChart.resize()
        })
        stackedChartObserver.observe(dom)
        return
    }

    // Re-assert the option (grid top included) and size on every mount/update
    // so the first visible paint is never stuck with the hidden-state layout.
    stackedChart.setOption(stackedChartOptions)
    stackedChart.resize()
}

document.addEventListener('DOMContentLoaded', initSystemChart)

window.TripwireCharts = window.TripwireCharts || {}
window.TripwireCharts.initSystemChart = initSystemChart
