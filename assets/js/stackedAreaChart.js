import * as echarts from 'echarts'

let stackedChart = null
let colorContext = null

function colorContext2d() {
    colorContext = colorContext || document.createElement("canvas").getContext("2d")
    return colorContext
}

function cssColor(name, fallback) {
    const raw = getComputedStyle(document.documentElement).getPropertyValue(name).trim()
    if (!raw) return fallback
    const context = colorContext2d()
    const sentinel = "#010203"
    context.fillStyle = sentinel
    context.fillStyle = raw
    return context.fillStyle === sentinel ? fallback : context.fillStyle
}

function withAlpha(color, alpha) {
    const context = colorContext2d()
    context.fillStyle = color
    const resolved = context.fillStyle
    if (resolved.startsWith("#")) {
        const red = parseInt(resolved.slice(1, 3), 16)
        const green = parseInt(resolved.slice(3, 5), 16)
        const blue = parseInt(resolved.slice(5, 7), 16)
        return `rgba(${red}, ${green}, ${blue}, ${alpha})`
    }
    const match = resolved.match(/rgba?\(([^)]+)\)/)
    if (!match) return resolved
    const [red, green, blue] = match[1].split(",").map(Number)
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`
}

function themeOption() {
    const ink = cssColor("--color-base-content", "#e4e4e8")
    const muted = withAlpha(ink, 0.62)
    const faint = withAlpha(ink, 0.12)
    const surface = cssColor("--color-base-200", "#1f1f23")
    const border = cssColor("--color-base-300", "#141417")

    return {
        textStyle: { color: muted },
        tooltip: {
            backgroundColor: surface,
            borderColor: border,
            textStyle: { color: ink, fontSize: 12 },
            axisPointer: { label: { backgroundColor: muted, color: surface } },
        },
        xAxis: [
            {
                axisLabel: { color: muted },
                axisLine: { lineStyle: { color: border } },
                splitLine: { show: false },
            },
        ],
        yAxis: [
            {
                axisLabel: { color: muted },
                axisLine: { show: false },
                splitLine: { lineStyle: { color: faint } },
            },
        ],
    }
}

function applyTheme() {
    if (stackedChart) stackedChart.setOption(themeOption())
}

const refreshChartTheme = () => requestAnimationFrame(() => applyTheme())

document.addEventListener("phx:set-mode", refreshChartTheme)
document.addEventListener("phx:set-theme", refreshChartTheme)

const stackedChartOptions = {
    backgroundColor: 'transparent',
    animationDurationUpdate: 100,
    grid: {
        top: '8%',
        bottom: 28,
        left: '4%',
        right: '4%',
        outerBoundsMode: 'same',
        outerBoundsContain: 'axisLabel',
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
}

const seriesTemplates = [
    { key: 'ship_kills', name: 'Ship Kills', color: '#ee6666' },
    { key: 'pod_kills', name: 'Pod Kills', color: '#fac858' },
    { key: 'jumps', name: 'Jumps', color: '#91cc75' },
    { key: 'npc_kills', name: 'NPC Kills', color: '#5470c6' },
]

function seriesOption({ key, name, color }, data) {
    return {
        id: key,
        name,
        type: 'line',
        stack: 'Total',
        symbol: 'circle',
        showSymbol: true,
        symbolSize: 6,
        color,
        lineStyle: { width: 2, color },
        itemStyle: { color: 'transparent', borderColor: color, borderWidth: 2 },
        areaStyle: { color, opacity: 0.25 },
        emphasis: {
            focus: 'series',
        },
        data: data || [],
    }
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
        hidden: parse('hidden'),
        values: {
            ship_kills: parse('shipKills'),
            pod_kills: parse('podKills'),
            jumps: parse('jumps'),
            npc_kills: parse('npcKills'),
        },
    }
}

function applyData({ labels, hidden, values }) {
    if (!stackedChart) return
    const hiddenSet = new Set(hidden || [])
    const series = seriesTemplates
        .filter(({ key }) => !hiddenSet.has(key))
        .map((template) => seriesOption(template, (values || {})[template.key]))

    stackedChart.setOption(
        {
            xAxis: [{ data: labels || [] }],
            series,
        },
        { replaceMerge: ['series'] }
    )
}

function initSystemChart(dom) {
    const target = dom || document.getElementById('system-chart')
    if (!target || stackedChart) {
        if (target && stackedChart) applyData(readDataset(target))
        return
    }

    stackedChart = echarts.init(target)
    stackedChart.setOption(stackedChartOptions)
    applyTheme()
    applyData(readDataset(target))
    window.TripwireCharts.instance = stackedChart

    new ResizeObserver(() => {
        if (stackedChart) stackedChart.resize()
    }).observe(target)
}

function updateSystemChart(payload) {
    if (!stackedChart || !payload) return
    applyData({
        labels: payload.labels || [],
        hidden: payload.hidden || [],
        values: {
            ship_kills: payload.ship_kills || [],
            pod_kills: payload.pod_kills || [],
            jumps: payload.jumps || [],
            npc_kills: payload.npc_kills || [],
        },
    })
}

document.addEventListener('DOMContentLoaded', () => initSystemChart())

window.TripwireCharts = window.TripwireCharts || {}
window.TripwireCharts.initSystemChart = initSystemChart
window.TripwireCharts.updateSystemChart = updateSystemChart
