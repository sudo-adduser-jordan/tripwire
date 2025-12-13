import * as echarts from 'echarts';

var stackedChartDom = document.getElementById('system-chart');
var stackedChart = echarts.init(stackedChartDom);
var stackedChartOptions = {
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
stackedChart.setOption(stackedChartOptions);

const resizeObserver = new ResizeObserver(() => {
    stackedChart.resize();
});

resizeObserver.observe(stackedChartDom);

