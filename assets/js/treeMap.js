

import * as echarts from 'echarts';
import $ from "jquery";


var chartDom = document.getElementById('map');
var treeMap = echarts.init(chartDom);
var option;

document.addEventListener('DOMContentLoaded', () => {


treeMap.showLoading();
$.get('/data.json', function (data) {
    treeMap.hideLoading();
    treeMap.setOption(
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

                    // scaleLimit: {min: 0.1, max:1},
                    roam: 'move',
                    // roam: 'pan',     
                    edgeShape: 'polyline',
                    //   lineStyle: {curveness: .5}
                }
            ],
        })
    );
});

option && treeMap.setOption(option);

})
