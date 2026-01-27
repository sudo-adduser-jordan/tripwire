import * as echarts from 'echarts';

function copySystemName(character){}


var stackedChartDom = document.getElementById('system-chart');
var stackedChart = echarts.init(stackedChartDom);
var stackedChartOptions = {
    animationDurationUpdate: 100,
    grid: {
        top: '10%',
        bottom: '20%',
        left: '7%',
        right: '7%',
        containLabel: false
    },
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
            data: [0, 0, 1, 6, 0, 0, 1]
        },
        {
            name: 'Pods Destroyed',
            type: 'line',
            stack: 'Total',
            areaStyle: {},
            emphasis: {
                focus: 'series'
            },
            data: [0, 0, 0, 5, 0, 0, 1]
        },
        {
            name: 'Jumps',
            type: 'line',
            stack: 'Total',
            areaStyle: {},
            emphasis: {
                focus: 'series'
            },
            data: [10, 15, 12, 50, 5, 1, 15]
        },
        {
            name: 'NPCs Destroyed',
            type: 'line',
            stack: 'Total',
            areaStyle: {},
            emphasis: {
                focus: 'series'
            },
            data: [150, 200, 100, 165, 250, 96, 153]
        },
    ]
};
stackedChart.setOption(stackedChartOptions);

stackedChart.init()

const stackedChartResizeObserver = new ResizeObserver(() => {
    stackedChart.resize();
});

stackedChartResizeObserver.observe(stackedChartDom);

