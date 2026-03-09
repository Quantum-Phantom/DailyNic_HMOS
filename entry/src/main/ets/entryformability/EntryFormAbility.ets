
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import ScheduleManager from '../utils/ScheduleManager';
import * as ScheduleSources from '../constants/ScheduleSources';
import examManager, { examAttribute } from '../utils/ExamManager';
import UnifiedPreferences, { millisecondsPerWeek } from '../utils/UnifyPreference';
import { CardListParameter } from '../class_schedule_daily/viewmodel/CardListParameter';

const TAG: string = 'EntryFormAbility';
const DOMAIN_NUMBER: number = 0xFF00;

class FormDataClass {
  todayCourse: ScheduleSources.classAttribute[] = [];
  tomorrowCourse: ScheduleSources.classAttribute[] = [];
  title: ResourceStr = '';
  count: number = 0;
  examInfo: examAttribute[] = [];
  lastRefresh: string = '';
  constructor(refreshType: number) {
    const currentTime = new Date();
    if (refreshType === 0) { // 0 → 刷新课表
      ScheduleManager.init();
      this.title = $r("app.string.schedule_card_title");
      const termStartTime: number = ScheduleManager.semesters[ScheduleManager.defaultSemester].beginTime;
      let currentWeek: number = 0;
      let termState: number = 1;
      if (currentTime.getTime() < termStartTime) {
        termState = 0;
        currentWeek = 1;
      } else if (currentTime.getTime() > termStartTime + ScheduleManager.semesters[ScheduleManager.defaultSemester].totalWeekNum * millisecondsPerWeek) {
        termState = 2;
        currentWeek = 1;
      } else {
        termState = 1;
        currentWeek = Math.ceil((currentTime.getTime() - termStartTime) / millisecondsPerWeek);
      }
      this.todayCourse = ScheduleManager.getDefaultClassByDay(currentWeek, currentTime.getDay());
      this.tomorrowCourse = ScheduleManager.getDefaultClassByDay(currentWeek + (currentTime.getDay() === 6 ? 1 : 0), (currentTime.getDay() + 1) % 7);

      //this.cardListParameter.itemCount = this.todayCourse.length;
      this.count = this.todayCourse.length;
    } else if (refreshType === 1) { // 1 → 刷新考试
      this.title = $r("app.string.exam_detail");
      examManager.readStoredExam();
      this.examInfo = examManager.allExamInfo;
      let currentTime: number = Date.now(); // 删除已结束考试
      for (let i = this.examInfo.length - 1; i >= 0; i--)
        if (currentTime > this.examInfo[i].endTimeStamp)
          this.examInfo.splice(i, 1);
      this.count = this.examInfo.length;
    }
    this.lastRefresh = '上次刷新: ' + currentTime.toLocaleString('zh-cn', { month: 'short', day: 'numeric', hour: 'numeric', minute: 'numeric' });
  }
}

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    // Called to return a FormBindingData object.
    const formName = want.parameters![formInfo.FormParam.NAME_KEY].toString();
    UnifiedPreferences.init(this.context)
    let data: FormDataClass = new FormDataClass(formName.includes('schedule') ? 0 : 1);
    return formBindingData.createFormBindingData(data);
  }

  onCastToNormalForm(formId: string) {
    // Called when the form provider is notified that a temporary form is successfully
    // converted to a normal form.
  }

  onUpdateForm(formId: string) {
    // Called to notify the form provider to update a specified form.
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN_NUMBER, TAG, `FormAbility onFormEvent, formId = ${formId}, message: ${JSON.stringify(message)}`);

    UnifiedPreferences.init(this.context)
    const eventSource: string = JSON.parse(message).msgTest
    let formData = new FormDataClass(eventSource === 'schedule' ? 0 : 1);

    const formInfo: formBindingData.FormBindingData = formBindingData.createFormBindingData(formData);
    formProvider.updateForm(formId, formInfo).then(() => {
      hilog.info(DOMAIN_NUMBER, TAG, 'FormAbility updateForm success.');
      console.info('FormAbility updateForm success')
    }).catch((error: Error) => {
      hilog.error(DOMAIN_NUMBER, TAG, `Operation updateForm failed. Cause: ${JSON.stringify(error)}`);
    });
  }

  onRemoveForm(formId: string) {
    // Called to notify the form provider that a specified form has been destroyed.
  }

  onAcquireFormState(want: Want) {
    // Called to return a {@link FormState} object.
    return formInfo.FormState.READY;
  }
}