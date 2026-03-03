import { classAttribute, obtainedData } from '../constants/ScheduleSources';
import { SCHEDULE_KEY, START_TIME_KEY, millisecondsPerWeek } from './UnifyPreference';
import UnifiedPreferences from './UnifyPreference';
import * as tools from './tools';

/**
 * 比较两个 classAttribute 对象是否完全相同
 * @param a 第一个对象
 * @param b 第二个对象
 * @returns 是否完全相同
 */
export function areClassAttributesEqual(a: classAttribute, b: classAttribute): boolean {
  // 基本类型直接比较
  if (a.name !== b.name) return false;
  if (a.teacher !== b.teacher) return false;
  if (a.dayOfWeek !== b.dayOfWeek) return false;
  if (a.location !== b.location) return false;
  if (a.id !== b.id) return false;
  if (a.color !== b.color) return false;
  if (a.priority !== b.priority) return false;

  // 数组类型通过辅助函数比较
  if (!tools.areNumberArraysEqual(a.weekOfTerm, b.weekOfTerm)) return false;
  if (!tools.areNumberArraysEqual(a.timeSpan, b.timeSpan)) return false;

  // 所有字段都相同
  return true;
}

export const example: string = '[[[{"name":"批判性思维与英语沟通","teacher":"Bradley Johnson","weekOfTerm":[2],"timeSpan":[1,2],"location":"5106","id":"FL1106A.01 [2]"}],[],[{"name":"数学分析(B1)","teacher":"王建伟","weekOfTerm":[2],"timeSpan":[3,4],"location":"5403","id":"MATH1006.08 [6]"}],[],[],[{"name":"计算机程序设计","teacher":"李卫海","weekOfTerm":[2],"timeSpan":[6,7],"location":"3A212","id":"CS1003.H2 [3]"}],[],[{"name":"力学A(L)","teacher":"王春成","weekOfTerm":[2],"timeSpan":[8,9],"location":"2106","id":"PHYS1001AL.01 [4]"}],[],[],[],[],[]],[[{"name":"力学A(L)","teacher":"王春成","weekOfTerm":[2],"timeSpan":[1,2],"location":"2106","id":"PHYS1001AL.01 [4]"}],[],[{"name":"线性代数(B1)","teacher":"赵晨","weekOfTerm":[2],"timeSpan":[3,4],"location":"3C103","id":"MATH1009.06 [4]"}],[],[],[],[],[{"name":"习近平新时代中国特色社会主义思想概论","teacher":"陈慧瑞","weekOfTerm":[2],"timeSpan":[8,9,10],"location":"1302","id":"MARX1014.06 [3]"}],[],[],[],[],[]],[[{"name":"数学分析(B1)","teacher":"王建伟","weekOfTerm":[2],"timeSpan":[1,2],"location":"5403","id":"MATH1006.08 [6]"}],[],[],[],[],[],[],[],[],[],[],[],[]],[[{"name":"线性代数(B1)","teacher":"赵晨","weekOfTerm":[2],"timeSpan":[1,2],"location":"3C103","id":"MATH1009.06 [4]"}],[],[{"name":"力学A(L)","teacher":"王春成","weekOfTerm":[2],"timeSpan":[3,4],"location":"2106","id":"PHYS1001AL.01 [4]"}],[],[],[{"name":"基础体育","teacher":"刘德海","weekOfTerm":[2],"timeSpan":[6,7],"location":"","id":"PE00001.28 [1]"}],[],[{"name":"思想道德与法治","teacher":"刘海龙","weekOfTerm":[2],"timeSpan":[8,9,10],"location":"1202","id":"MARX1012.12 [2.5]"}],[],[],[],[],[]],[[],[],[{"name":"数学分析(B1)","teacher":"王建伟","weekOfTerm":[2],"timeSpan":[3,4],"location":"5403","id":"MATH1006.08 [6]"}],[],[],[{"name":"计算机程序设计","teacher":"李卫海","weekOfTerm":[2],"timeSpan":[6,7],"location":"3A212","id":"CS1003.H2 [3]"}],[],[{"name":"先进制造实践","teacher":"倪青, 刘志刚, ...","weekOfTerm":[2],"timeSpan":[8,9,10],"location":"","id":"ME2503.01 [2]"}],[],[],[],[],[]],[[],[],[],[],[],[],[],[],[],[],[],[],[]],[[],[],[],[],[],[],[],[],[],[],[],[],[]]]'

class scheduleManager {
  weekDisplayed: number = 0;
  termStart: number = 0;
  weekStart: number = 0;
  weekEnd: number = 0;
  parsedSchedule: classAttribute[][][] = [[[]]];
  formattedSchedule: classAttribute[][][] = [[[]]]; // 第一层：周数；第二层：星期几；第三层：这一天的所有课，在Schedule.ets中会按优先级排序
  currentTime: Date = new Date();
  today: number = 0; // 星期几-1
  isTermBegin: boolean = true;
  isTermEnd: boolean = false;
  finalWeek: number = 0;

  getParsedSchedule(): void {
    this.parsedSchedule = JSON.parse(UnifiedPreferences.getSync(SCHEDULE_KEY, '[[[]]]')) as classAttribute[][][];
    if (UnifiedPreferences.hasSync(START_TIME_KEY)) {
      this.weekDisplayed = Math.ceil((this.currentTime.getTime() - Number(UnifiedPreferences.getSync(START_TIME_KEY))) / millisecondsPerWeek);
      this.finalWeek = UnifiedPreferences.getNumberSync('FinalWeek', 0);
      if (this.weekDisplayed > this.finalWeek) { // 学期已结束 (此处本来是>20)
        if (this.weekDisplayed > 20)
          this.weekDisplayed = 1;
        this.isTermBegin = true;
        this.isTermEnd = true;
      } else if (this.weekDisplayed <= 0) { // 学期未开始
        this.weekDisplayed = 1;
        this.isTermBegin = false;
        this.isTermEnd = false;
      } else { // 学期已开始，this.weekDisplayed在可接受范围内
        this.isTermBegin = true;
        this.isTermEnd = false;
      }
      this.weekStart = Number(UnifiedPreferences.getSync(START_TIME_KEY)) + (this.weekDisplayed - 1) * millisecondsPerWeek;
      this.termStart = Number(UnifiedPreferences.getSync(START_TIME_KEY));
    } else { // 没有保存学期开始时间时，以上一个星期日为学期开始时间
      this.weekDisplayed = 1;
      const monday = new Date(this.currentTime);
      monday.setDate(this.currentTime.getDate() + (this.currentTime.getDay() === 0 ? 1 : - (this.currentTime.getDay() - 1)));
      monday.setHours(0, 0, 0, 0);
      this.weekStart = monday.getTime() - 86400000;
      UnifiedPreferences.putSync(START_TIME_KEY, this.weekStart);
      this.termStart = this.weekStart;
      this.isTermBegin = true;
      this.isTermEnd = false;
    }
    this.today = (this.currentTime.getDay() + 6) % 7;
    this.weekEnd = this.weekStart + 518400000;
  }

  refreshParsedSchedule(routerParams: obtainedData): void {
    try {
      const timeTable = routerParams.timeTable.slice(1, -1).replace(/\\/g, '');
      this.termStart = Number(routerParams.startTime/*.replace(/[^0-9]/g, '')*/);
      this.parsedSchedule = JSON.parse(timeTable) as classAttribute[][][];

      let courseToColor = new Map<string, string>();
      let randColor: number = tools.getRandomInt(0, tools.colorSetLen - 1);
      this.finalWeek = 0;
      for (let i of this.parsedSchedule)
        if (i != null)
          for (let j of i)
            if (j != null)
              for (let k of j) {
                if (k.color == undefined) {
                  if (courseToColor.has(k.name)) {
                    k.color = courseToColor.get(k.name) as string;
                  } else {
                    k.color = tools.colorSet[randColor];
                    randColor = (randColor + 1) % tools.colorSetLen;
                    courseToColor.set(k.name, k.color);
                  }
                }
                if (k.priority == undefined)
                  k.priority = 5;
                 this.finalWeek = Math.max(k.weekOfTerm[k.weekOfTerm.length - 1], this.finalWeek);
              }

      UnifiedPreferences.putSync('FinalWeek', this.finalWeek);
      UnifiedPreferences.putSync(SCHEDULE_KEY, JSON.stringify(this.parsedSchedule));
      UnifiedPreferences.putSync('ScheduleVersion', '2.0.0');
      this.weekDisplayed = Math.ceil((this.currentTime.getTime() - this.termStart) / millisecondsPerWeek);
      if (this.weekDisplayed > this.finalWeek) { // 未设置，或者学期已结束 (此处本来是>20)
        if (this.weekDisplayed > 20)
          this.weekDisplayed = 1;
        if (this.termStart == 0 ) { // 如果没有学期开始信息（默认是0）（即手动添加第一门课），将上一个周日作为一周开始
          const monday = new Date(this.currentTime);
          monday.setDate(this.currentTime.getDate() + (this.currentTime.getDay() === 0 ? 1 : -(this.currentTime.getDay() - 1)));
          monday.setHours(0, 0, 0, 0);
          UnifiedPreferences.putSync(START_TIME_KEY, monday.getTime() - 86400000);
          this.isTermBegin = true;
          this.isTermEnd = false;
        } else { // 如果有，说明学期结束
          UnifiedPreferences.putSync(START_TIME_KEY, this.termStart);
          this.isTermBegin = true;
          this.isTermEnd = true;
        }
      } else { // 学期未结束
        if (this.weekDisplayed <= 0) { // 学期未开始
          this.weekDisplayed = 1;
          this.isTermBegin = false;
        } else { // 学期已开始
          this.isTermBegin = true;
        }
        UnifiedPreferences.putSync(START_TIME_KEY, this.termStart);
        this.isTermEnd = false;
      }
      this.weekStart = UnifiedPreferences.hasSync(START_TIME_KEY)
        ? Number(UnifiedPreferences.getSync(START_TIME_KEY)) + (this.weekDisplayed - 1) * millisecondsPerWeek
        : this.currentTime.getTime();
      this.weekEnd = this.weekStart + 518400000;
    } catch (err) {
      console.error('parsed');
    }
  }

  getFormattedSchedule(): void {
    this.currentTime = new Date();
    this.getParsedSchedule();
    this.formattedSchedule = [];
    for (let i = 0; i <= 21; i++) { // 初始化三个维度
      this.formattedSchedule[i] = [];
      for (let j = 0; j <= 6; j++)
        this.formattedSchedule[i][j] = [];
    }
    for (let i = 0; i <= 6; i++) // 星期几 -1
      if (this.parsedSchedule[i] != undefined) // 防止不存在元素
        for (let j of this.parsedSchedule[i]) // 星期几的每一节课
          if (j != undefined)
            for (let k of j) // 叠课判断
              for (let week of k.weekOfTerm)
                this.formattedSchedule[week][i].push(k);
  }

  addSchedule(toChangeInfo: classAttribute, changeAllColor: boolean) {
    let i: number = toChangeInfo.dayOfWeek;
    let j: number = toChangeInfo.timeSpan[0] - 1;
    if (this.parsedSchedule[i] == undefined)
      this.parsedSchedule[i] = [];
    if (this.parsedSchedule[i][j] == undefined)
      this.parsedSchedule[i][j] = [];
    this.parsedSchedule[i][j].push(toChangeInfo);

    if (changeAllColor)
      for (let i of this.parsedSchedule)
        if (i != null)
          for (let j of i)
            if (j != null)
              for (let k of j)
                if (k.name === toChangeInfo.name)
                  k.color = toChangeInfo.color;

    // 添加当前显示的课程
    this.refreshParsedSchedule({ timeTable: `[${JSON.stringify(this.parsedSchedule)}]`, startTime: this.termStart.toString() });
    this.getFormattedSchedule();
    // 保存到对应课表中
  }

  deleteSchedule(oriClassInfo: classAttribute) {
    let i: number = oriClassInfo.dayOfWeek;
    let j: number = oriClassInfo.timeSpan[0] - 1;
    for (let k = this.parsedSchedule[i][j].length - 1; k >= 0; k--)
      if (areClassAttributesEqual(oriClassInfo, this.parsedSchedule[i][j][k])) {
        this.parsedSchedule[i][j].splice(k, 1);
        break;
      }
    this.refreshParsedSchedule({ timeTable: `[${JSON.stringify(this.parsedSchedule)}]`, startTime: this.termStart.toString() });
    this.getFormattedSchedule();
  }

  updateChange(currentVer: string) {
    const oldVer = UnifiedPreferences.getSync('ScheduleVersion');
    if (oldVer === '1.0.0') {
      this.finalWeek = 0;
      for (let i of this.parsedSchedule)
        if (i != null)
          for (let j of i)
            if (j != null)
              for (let k of j)
                this.finalWeek = Math.max(k.weekOfTerm[k.weekOfTerm.length - 1], this.finalWeek);
      UnifiedPreferences.putSync('FinalWeek', this.finalWeek);
    }
  }


  defaultSemester: number = UnifiedPreferences.getNumberSync('DefaultSemester', 0);
  addingTimestamp: number[] = JSON.parse(UnifiedPreferences.getSync('AddingTimestamp', '[]')) as number[];

  switchSemester(targetTimestamp: number) {
    this.refreshParsedSchedule({ timeTable: `[${UnifiedPreferences.getSync(`ScheduleDataAt${targetTimestamp}`, '[[[]]]')}]`, startTime: UnifiedPreferences.getNumberSync(`ScheduleTimeAt${targetTimestamp}`, 0).toString() });
    this.defaultSemester = targetTimestamp;
    UnifiedPreferences.putSync('DefaultSemester', targetTimestamp);
  }

  editSemester(timestamp: number, timeTable: string, startTime: number, isReplace: boolean) {
    timeTable = timeTable.replace(/\\"/g, '"');
    if (!UnifiedPreferences.hasSync(`ScheduleDataAt${timestamp}`) || isReplace) {
      UnifiedPreferences.putSync(`ScheduleDataAt${timestamp}`, timeTable);
    } else {
      console.log('!!!' + timeTable);
      let parsedTimetable: classAttribute[][][] = JSON.parse(timeTable);
      let originTimetable: classAttribute[][][] = JSON.parse(UnifiedPreferences.getSync(`ScheduleDataAt${timestamp}`, '[[[]]]'));

      let flag: boolean[][][] = [];
      for (let i = 0; i <= 20; i++) { // 初始化三个维度
        flag[i] = [];
        for (let j = 0; j <= 6; j++)
          flag[i][j] = new Array(14).fill(false);
      }

      originTimetable.forEach(layer1 => {
        layer1?.forEach(layer2 => {
          layer2?.forEach(i => {
            i.weekOfTerm.forEach(week => {
              i.timeSpan.forEach(section => {
                flag[week][i.dayOfWeek][section] = true;
              });
            });
          });
        });
      });

      parsedTimetable.forEach(layer1 => {
        layer1?.forEach(layer2 => {
          layer2?.forEach(i => {
            let noConflict = true;
            toBreak: for (let week of i.weekOfTerm) {
              for (let section of i.timeSpan) {
                if (flag[week][i.dayOfWeek][section]) { // 如果已经被占用了
                  noConflict = false;
                  break toBreak;
                }
              }
            }
            if (noConflict)
              originTimetable[i.dayOfWeek][i.timeSpan[0]].push(i);
          });
        });
      });

      UnifiedPreferences.putSync(`ScheduleDataAt${timestamp}`, JSON.stringify(originTimetable));
    }
  }

  newSemester(timeTable: string, startTime: number, name: string) {
    this.currentTime = new Date();
    const timestamp = this.currentTime.getTime();
    UnifiedPreferences.putSync(`ScheduleDataAt${timestamp}`, timeTable);
    UnifiedPreferences.putSync(`ScheduleTimeAt${timestamp}`, startTime);
    UnifiedPreferences.putSync(`ScheduleNameAt${timestamp}`, name);
    this.addingTimestamp.push(timestamp);
    UnifiedPreferences.putSync('AddingTimestamp', JSON.stringify(this.addingTimestamp));
  }
}

export default new scheduleManager();