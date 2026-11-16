import * as echarts from 'echarts'

let stackedChart = null

const stackedChartOptions = {
    backgroundColor: 'transparent',
    animationDurationUpdate: 100,
    grid: {
        top: '8%',
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
        show: false,
    },
    xAxis: [
        {
            type: 'category',
            boundaryGap: false,
            data: [],
        },
    ],
    yAxis: [
        {
            type: 'value',
        },
    ],
    series: [
        {
            name: 'Ship Kills',
            type: 'line',
            stack: 'Total',
            symbol: 'circle',
            showSymbol: true,
            symbolSize: 6,
            color: '#ee6666',
            lineStyle: { width: 2, color: '#ee6666' },
            itemStyle: { color: 'transparent', borderColor: '#ee6666', borderWidth: 2 },
            areaStyle: { color: '#ee6666', opacity: 0.25 },
            emphasis: {
                focus: 'series',
            },
            data: [],
        },
        {
            name: 'Pod Kills',
            type: 'line',
            stack: 'Total',
            symbol: 'circle',
            showSymbol: true,
            symbolSize: 6,
            color: '#fac858',
            lineStyle: { width: 2, color: '#fac858' },
            itemStyle: { color: 'transparent', borderColor: '#fac858', borderWidth: 2 },
            areaStyle: { color: '#fac858', opacity: 0.25 },
            emphasis: {
                focus: 'series',
            },
            data: [],
        },
        {
            name: 'Jumps',
            type: 'line',
            stack: 'Total',
            symbol: 'circle',
            showSymbol: true,
            symbolSize: 6,
            color: '#91cc75',
            lineStyle: { width: 2, color: '#91cc75' },
            itemStyle: { color: 'transparent', borderColor: '#91cc75', borderWidth: 2 },
            areaStyle: { color: '#91cc75', opacity: 0.25 },
            emphasis: {
                focus: 'series',
            },
            data: [],
        },
        {
            name: 'NPC Kills',
            type: 'line',
            stack: 'Total',
            symbol: 'circle',
            showSymbol: true,
            symbolSize: 6,
            color: '#5470c6',
            lineStyle: { width: 2, color: '#5470c6' },
            itemStyle: { color: 'transparent', borderColor: '#5470c6', borderWidth: 2 },
            areaStyle: { color: '#5470c6', opacity: 0.25 },
            emphasis: {
                focus: 'series',
            },
            data: [],
        },
    ],
}

function readDataset(dom) {
    const parse = (key) => {
        try {
            const raw = dom.dataset[key]
            const value = raw ? JSON.parse(raw) : []
            return Array.isArray(value) ? value : []
        } catch {
            return []
        }
    }
    return {
        labels: parse('labels'),
        shipKills: parse('shipKills'),
        podKills: parse('podKills'),
        jumps: parse('jumps'),
        npcKills: parse('npcKills'),
    }
}

function applyData({ labels, shipKills, podKills, jumps, npcKills }) {
    if (!stackedChart) return
    stackedChart.setOption({
        xAxis: [{ data: labels }],
        series: [{ data: shipKills }, { data: podKills }, { data: jumps }, { data: npcKills }],
    })
}

function initSystemChart(dom) {
    const target = dom || document.getElementById('system-chart')
    if (!target || stackedChart) {
        if (target && stackedChart) applyData(readDataset(target))
        return
    }

    stackedChart = echarts.init(target)
    stackedChart.setOption(stackedChartOptions)
    applyData(readDataset(target))

    new ResizeObserver(() => {
        if (stackedChart) stackedChart.resize()
    }).observe(target)
}

function updateSystemChart(payload) {
    if (!stackedChart || !payload) return
    const hidden = new Set(payload.hidden || [])
    const mask = (key, values) => (hidden.has(key) ? (values || []).map(() => 0) : values || [])
    applyData({
        labels: payload.labels || [],
        shipKills: mask('ship_kills', payload.ship_kills),
        podKills: mask('pod_kills', payload.pod_kills),
        jumps: mask('jumps', payload.jumps),
        npcKills: mask('npc_kills', payload.npc_kills),
    })
}

document.addEventListener('DOMContentLoaded', () => initSystemChart())

window.TripwireCharts = window.TripwireCharts || {}
window.TripwireCharts.initSystemChart = initSystemChart
window.TripwireCharts.updateSystemChart = updateSystemChart
