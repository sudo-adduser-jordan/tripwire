import * as echarts from 'echarts';
import $ from "jquery";

var treeMapDom = document.getElementById('treeMap');
var treeMap = echarts.init(treeMapDom);
var treeMapOptions;

treeMap.showLoading();
$.get('/data.json', (data) => {
    treeMap.hideLoading();

    treeMapOptions = {
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
                    formatter: '{b} \n{c}'
                },
                left: '-25%',
                right: '-25%',
                top: '10%',
                bottom: '20%',
                symbol: 'roundRect',
                symbolSize: [100, 60],
                roam: 'move',
                edgeShape: 'polyline',
            }
        ],
    }
    treeMap.setOption(treeMapOptions)
});

const resizeObserver = new ResizeObserver(() => {
    treeMap.resize();
});
resizeObserver.observe(treeMapDom);

