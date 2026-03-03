// 用于管理多学期的 ScheduleManager

import UnifyPreferences from './UnifyPreference';
import { classAttribute, semesterAttribute } from '../constants/ScheduleSources';

function areNumberArraysEqual(a: number[], b: number[]): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

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
  if (a.credits !== b.credits) return false;

  // 数组类型通过辅助函数比较
  if (!areNumberArraysEqual(a.weekOfTerm, b.weekOfTerm)) return false;
  if (!areNumberArraysEqual(a.timeSpan, b.timeSpan)) return false;

  // 所有字段都相同
  return true;
}

class ScheduleManager {
  // 所有学期
  semesters: semesterAttribute[];
  // 课表页展示的默认课程（number是当前周数），通过getClassesByWeek获取整周的课程
  weekDayIndex: Map<number, Map<number, classAttribute[]>>;
  // UI展示的默认课程（number是当前周数），通过getClassesByWeek获取整周的课程
  defaultIndex: Map<number, Map<number, classAttribute[]>> = new Map<number, Map<number, classAttribute[]>>();
  // 当前展示学期的编号
  displaySemester: number;

  // 以下内容针对首页/服务卡片/系统日程添加
  // 默认学期的编号，通过semesters[defaultSemester]读取
  defaultSemester: number = 0;


  constructor() {
    // 读取所有学期的信息
    this.semesters = JSON.parse(UnifyPreferences.getSync('SemestersData', '[]')) as semesterAttribute[];
    this.setDefaultSemester(this.displaySemester = UnifyPreferences.getNumberSync('DefaultSemester', 0)); // 默认第一个是课表
    if (this.semesters.length === 0) { // 如果是第一次使用
      const currentTime = new Date();
      this.newSemester('默认', '初始自动生成', new Date(new Date(currentTime).setDate(currentTime.getDate() - currentTime.getDay())).setHours(0, 0, 0, 0), currentTime.getTime());
    }
    this.weekDayIndex = new Map<number, Map<number, classAttribute[]>>();
    this.rebuildIndex(JSON.parse(UnifyPreferences.getSync('SemesterDataAt' + String(this.semesters[this.displaySemester].createTime), '[]')) as classAttribute[]);
  }


  /**
   * 根据课程列表重建周索引
   * @param classes 课程列表
   * @returns undefined，但如果发生错误则返回错误信息的字符串
   */
  private rebuildIndex(classes: classAttribute[]): string | undefined {
    try {
      this.weekDayIndex.clear();
      for (const classItem of classes) {
        if (!classItem) {
          continue; // 跳过无效的课程项
        }
        for (const week of classItem.weekOfTerm) {
          let dayMap = this.weekDayIndex.get(week);
          if (!dayMap) {
            dayMap = new Map();
            this.weekDayIndex.set(week, dayMap);
          }
          let classList = dayMap.get(classItem.dayOfWeek);
          if (!classList) {
            classList = [];
            dayMap.set(classItem.dayOfWeek, classList);
          }
          classList.push(classItem);
        }
      }
      return;
    } catch(err) {
      return JSON.stringify(err);
    }
  }


  /**
   * 获取指定周的所有课程
   * @param week 周数
   * @returns 课程列表
   */
  getClassesByWeek(week: number): classAttribute[] {
    const dayMap = this.weekDayIndex.get(week);
    if (!dayMap)
      return [];
    const result: classAttribute[] = [];
    for (const classesOfDay of dayMap.values()) {
      result.push(...classesOfDay);
    }
    return result;
  }

  /**
   * 获取指定周和天的课程
   * @param week 周数
   * @param day 星期几
   * @returns 课程列表
   */
  getClassByDay(week: number, day: number): classAttribute[] {
    return this.weekDayIndex.get(week)?.get(day) || [];
  }

  /**
   * 创建新学期
   * @param name 学期名称
   * @param source 来源
   * @param beginTime 开始时间戳
   * @param createTime 创建时间戳
   * @param totWeekNum 总周数
   * @param timetable 课程表
   * @returns undefined，但如果发生错误则返回错误信息的字符串
   */
  newSemester(name: string, source: string, beginTime: number, createTime: number, totWeekNum: number = 0, timetable?: classAttribute[]): string | undefined {
    try {
      const semesterConfig: semesterAttribute = {
        name: name,
        source: source,
        createTime: createTime,
        beginTime: beginTime,
        totalWeekNum: totWeekNum
      };
      this.semesters.push(semesterConfig);
      UnifyPreferences.putSync('SemestersData', JSON.stringify(this.semesters));
      UnifyPreferences.putSync('SemesterDataAt' + String(createTime), timetable ? JSON.stringify(timetable) : '[]');
      return;
    } catch(err) {
      return JSON.stringify(err);
    }
  }

  /**
   * 覆盖或合并指定学期的课程数据
   * @param id 学期索引
   * @param newSchedule 新课程列表
   * @param insert 是否为合并模式（true为合并，false为覆盖，默认false）
   * @returns undefined，但如果发生错误则返回错误信息的字符串
   */
  coverExistSemester(id: number, newSchedule: classAttribute[], insert: boolean = false): string | undefined {
    try {
      if (insert) {
        const originSchedule: classAttribute[] = JSON.parse(UnifyPreferences.getSync('SemesterDataAt' + String(this.semesters[id].createTime), '[]'));
        for (const originClass of originSchedule) {
          // 检查是否已存在相同的课程
          const exists: boolean = originSchedule.some(newClass => areClassAttributesEqual(originClass, newClass));
          if (!exists) {
            originSchedule.push(originClass);
          }
        }
        if (id === this.displaySemester)
          return this.rebuildIndex(newSchedule);
      } else { // 直接覆盖
        UnifyPreferences.putSync('SemesterDataAt' + String(this.semesters[id].createTime), JSON.stringify(newSchedule));
        if (id === this.displaySemester)
          return this.rebuildIndex(newSchedule);
      }
      return;
    } catch(err) {
      return JSON.stringify(err);
    }
  }

  /**
   * 临时切换课表，用于在功能页查看
   * @param target 目标学期索引
   * @returns undefined，但如果发生错误则返回错误信息的字符串
   */
  switchTempSemester(target: number): string | undefined {
    try {
      this.displaySemester = target;
      this.rebuildIndex(JSON.parse(UnifyPreferences.getSync('SemesterDataAt' + String(this.semesters[target].createTime), '[]')) as classAttribute[]);
      return;
    } catch(err) {
      return JSON.stringify(err);
    }
  }

  /**
   * 初始化或切换默认课表，将会用于首页、添加日程以及桌面卡片
   * @param target 目标学期索引
   * @returns undefined，但如果发生错误则返回错误信息的字符串
   */
  setDefaultSemester(target: number, changeDefault: boolean = false): string | undefined {
    try {
      if (changeDefault)
        UnifyPreferences.putSync('DefaultSemester', target);
      this.defaultSemester = target;
      this.defaultIndex.clear();
      const classes: classAttribute[] = JSON.parse(UnifyPreferences.getSync('SemesterDataAt' + String(this.semesters[target].createTime), '[]'));
      for (const classItem of classes) {
        for (const week of classItem.weekOfTerm) {
          if (!this.defaultIndex.has(week)) {
            this.defaultIndex.set(week, new Map());
          }
          const dayMap = this.defaultIndex.get(week)!;

          if (!dayMap.has(classItem.dayOfWeek)) {
            dayMap.set(classItem.dayOfWeek, []);
          }
          dayMap.get(classItem.dayOfWeek)!.push(classItem);
        }
      }
      return;
    } catch(err) {
      return JSON.stringify(err);
    }
  }

  /**
   * 获取课程列表中的最大周数
   * @param timetable 课程列表
   * @returns 最大周数（数字），如果发生错误则返回-1
   */
  getLatestWeek(timetable: classAttribute[]): number {
    try {
      let latestWeek: number = 0;
      timetable.forEach(singleClass => {
        latestWeek = Math.max(latestWeek, singleClass.weekOfTerm[singleClass.weekOfTerm.length - 1]);
      })
      return latestWeek;
    } catch(err) {
      return -1;
    }
  }

  /**
   * 向指定学期添加一门课程
   * @param id 学期索引
   * @param newClass 新课程
   * @returns undefined，但如果发生错误则返回错误信息的字符串
   */
  addClassToSemester(id: number, newClass: classAttribute, changeAllColor: boolean = false): string | undefined {
    try {
      const originClass: classAttribute[] = JSON.parse(UnifyPreferences.getSync('SemesterDataAt' + String(this.semesters[id].createTime), '[]'));
      if (changeAllColor) {
        originClass.forEach(singleClass => {
          if (singleClass.name === newClass.name)
            singleClass.color = newClass.color;
        });
      }
      originClass.push(newClass);
      return this.coverExistSemester(id, originClass, false);
    } catch(err) {
      return JSON.stringify(err);
    }
  }

  /**
   * 向指定学期删除一门课程
   * @param id 学期索引
   * @param removingClass 新课程
   * @returns 删除成功无返回值，如果未找到课程则返回'NotFound'，如果发生错误则返回错误信息的字符串
   */
  deleteClassFromSemester(id: number, removingClass: classAttribute): string | undefined {
    try {
      const originClass: classAttribute[] = JSON.parse(UnifyPreferences.getSync('SemesterDataAt' + String(this.semesters[id].createTime), '[]'));
      let hasEqualClass: boolean = false;
      for (let i = originClass.length - 1; i >= 0; i--)
        if (areClassAttributesEqual(originClass[i], removingClass)) {
          originClass.splice(i, 1);
          hasEqualClass = true;
          break;
        }
      if (hasEqualClass)
        return this.coverExistSemester(id, originClass, false);
    } catch(err) {
      return JSON.stringify(err);
    }
    return 'NotFound';
  }

  changeSemesterStartTime(id: number, newStartTime: number): string | undefined {
    try {
      this.semesters[id].beginTime = newStartTime;
      UnifyPreferences.putSync('SemestersData', JSON.stringify(this.semesters));
      return;
    } catch(err) {
      return JSON.stringify(err);
    }
  }

  deleteSemester(id: number): string | undefined {
    try {
      if (id === this.displaySemester || id === this.defaultSemester)
        return 'Occupied';
      UnifyPreferences.deleteSync('SemesterDataAt' + String(this.semesters[id].createTime));
      if (this.displaySemester > id)
        this.displaySemester--;
      if (this.defaultSemester > id)
        this.defaultSemester--;
      this.semesters.splice(id, 1);
      UnifyPreferences.putSync('SemestersData', JSON.stringify(this.semesters));
      return;
    } catch(err) {
      return JSON.stringify(err);
    }
  }

  renameSemester(id: number, newName: string): string | undefined {
    try {
      this.semesters[id].name = newName;
      UnifyPreferences.putSync('SemestersData', JSON.stringify(this.semesters));
      return;
    } catch(err) {
      return JSON.stringify(err);
    }
  }
}

export default new ScheduleManager();