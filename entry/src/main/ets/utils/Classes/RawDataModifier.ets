interface bilingual {
  cn: string,
  en?: string
}

interface courseIF extends bilingual {
  id: number,
  code: string
}

interface departmentIF extends bilingual {
  college: boolean,
  code: string
}

interface TALI extends bilingual {
  departmentCode: string
}

export interface courseFromJW {
  id: number,
  code: string,
  period: number,
  periodsPerWeek: number,
  credits: number,
  dateTimePlaceText: string,
  dateTimePlacePersonText: bilingual, // 无en属性
  stdCount: number,
  limitCount: number,
  graduateAndPostgraduate: boolean,
  course: courseIF,
  courseType: bilingual,
  courseGradation: bilingual,
  courseCategory: bilingual,
  courseClassify: bilingual,
  openDepartment: departmentIF,
  campus: bilingual,
  examMode: bilingual,
  teachLang: bilingual,
  education: bilingual,
  classType: bilingual,
  teacherAssignmentList: TALI[],
  adminClasses: bilingual[]
}

export interface searchOption {
  className?: string,
  teacherName?: string,
  dayOfWeek?: number[],
  timeSpan?: number[],
  caseSensitive?: boolean,
  weekType?: 'single' | 'double' | 'all', // 新增：单周/双周/全部
  maxAmount?: number
}

interface DTW {
  dayOfWeek: number[];
  timeSpan: number[];
  weekType: 'single' | 'double' | 'all'; // 单周/single | 双周/double | 全部/all
}

/**
 * 解析时间地点文本（支持单双周）
 * @param dateTimeText 格式示例："1~5,9~11(单),12~15周 1101 :3(3,4,5) 丁兆君"
 * @returns 解析结果（星期、节次、单双周）
 */
const parseDateTimeText = (dateTimeText: string): DTW | undefined => {
  const result: DTW = {
    dayOfWeek: [] as number[],
    timeSpan: [] as number[],
    weekType: 'all' as 'single' | 'double' | 'all'
  };
  if (!dateTimeText)
    return undefined;

  // 1. 解析单双周
  const weekTypeMatch = dateTimeText.match(/(\d+~\d+)\((单|双)\)/);
  if (weekTypeMatch) {
    result.weekType = weekTypeMatch[2] === '单' ? 'single' : 'double';
  }

  // 2. 解析星期（:3(3,4,5) 中第一个数字是星期）
  const dayMatch = dateTimeText.match(/:(\d+)\(/);
  if (dayMatch && dayMatch[1]) {
    const day = parseInt(dayMatch[1], 10);
    if (!isNaN(day)) result.dayOfWeek.push(day);
  }

  // 3. 解析节次（(3,4,5) 中的数字）
  const timeMatch = dateTimeText.match(/\(([^)]+)\)/);
  if (timeMatch && timeMatch[1]) {
    // 排除单双周的括号，只取节次括号内容
    const timeStr = timeMatch[1].split(',').filter(item => !isNaN(Number(item)));
    const timeNumbers = timeStr.map(num => parseInt(num, 10));
    result.timeSpan.push(...timeNumbers.filter(num => !isNaN(num)));
  }

  return result;
};

/**
 * 筛选courseFromJW数组（支持单双周、忽略英文大小写）
 * @param courseList 待筛选数组
 * @param options 搜索条件
 * @returns 符合条件的课程数组
 */
export const searchCourses = (courseList: courseFromJW[], options: searchOption): courseFromJW[] => {
  const result: courseFromJW[] = [];
  const maxCount = options.maxAmount || 200;
  for (const course of courseList) {
    // 最多只收集 200 条
    if (result.length >= maxCount) break;

    // 筛选课程名称
    if (options.className) {
      let courseName = course.course.cn;
      if (!options.caseSensitive)
        courseName = courseName.replace(/[A-Z]/g, char => char.toLowerCase());

      const targetName: string = options.caseSensitive
        ? options.className
        : options.className.replace(/[A-Z]/g, char => char.toLowerCase());
      if (!courseName.includes(targetName)) continue;
    }

    // 筛选教师姓名（仅cn字段）
    if (options.teacherName) {
      const hasMatchTeacher = course.teacherAssignmentList.some(teacher => {
        let teacherCn = teacher.cn;
        if (!options.caseSensitive) {
          teacherCn = teacherCn.replace(/[A-Z]/g, char => char.toLowerCase());
        }
        const targetTeacher = options.caseSensitive
          ? options.teacherName!
          : options.teacherName!.replace(/[A-Z]/g, char => char.toLowerCase());
        return teacherCn.includes(targetTeacher);
      });
      if (!hasMatchTeacher) continue;
    }

    if (options.dayOfWeek) {
      const parseResult = parseDateTimeText(course.dateTimePlacePersonText.cn);
      if (parseResult) {
        // 筛选星期
        if (options.dayOfWeek && options.dayOfWeek.length > 0) {
          const isDayMatch = options.dayOfWeek.some(day => parseResult.dayOfWeek.includes(day));
          if (!isDayMatch) continue;
        }

        // 筛选节次
        if (options.timeSpan && options.timeSpan.length > 0)
          if (!options.timeSpan.some(time => parseResult.timeSpan.includes(time))) continue;

        // 筛选单双周
        if (options.weekType !== 'all' && parseResult.weekType !== options.weekType) continue;
      }
    }

    result.push(course);
  }
  return result;
};

let searchDebounceTimer: number | null = null;
/**
 * 防抖调用课程搜索函数（专为你的 searchCourses 定制）
 * @param courseList 课程数组
 * @param options 搜索条件
 * @param callback 搜索完成后的回调
 */
export function debounceSearchCourses(
  courseList: courseFromJW[],
  options: searchOption,
  callback: (result: courseFromJW[]) => void,
  delay: number = 1000
) {
  // 清除上一次定时器
  if (searchDebounceTimer !== null) {
    clearTimeout(searchDebounceTimer);
  }

  // 新建定时器
  searchDebounceTimer = setTimeout(() => {
    console.error('debounce !')
    // 直接调用你的搜索函数
    const result = searchCourses(courseList, options);
    // 把结果传给回调
    callback(result);
  }, delay);
}