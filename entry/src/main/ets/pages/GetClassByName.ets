import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import BackgroundImage from '../utils/BgImageManager';
import { debounce } from '../utils/tools';


@Builder
export function GCBNBuilder(name: string, param?: object) {
  GetClassByName();
}

enum SearchStatus {
  LOADING,
  WAITING_FOR_INPUT,
  GET_DATA_FAILED,
  QUERYING,
  QUERY_SUCCESS,
  NO_RESULT,
  DATA_FORMAT_ERR
}

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

interface TALIF extends bilingual {
  departmentCode: string
}

interface courseFromJW {
  id: number,
  code: string,
  period: number,
  periodsPerWeek: number,
  credits: number,
  dateTimePlaceText: string,
  dateTimePlacePersonText: bilingual, // 这个值没有属性en！！！
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
  teacherAssignmentList: TALIF[],
  adminClasses: bilingual[]
}


@Entry
@Component
struct GetClassByName {

  className: string = '';
  @State requestStatus: SearchStatus = SearchStatus.LOADING;
  obtainedData: courseFromJW[] = [];
  @State shownData: courseFromJW[] = [];
  @State resultCount: number = 0;

  pathStack: NavPathStack = new NavPathStack();
  build() {
    NavDestination() {
      Column() {
        if (this.requestStatus === SearchStatus.GET_DATA_FAILED) {
          Image($r('app.media.sorry'))
            .width(100)
            .margin({ top: 16 })
          Text() {
            Span('由于接口限制，非校园网环境无法获取课程列表，请连接校园网后')
            Span('重试')
              .fontColor($r('app.color.active_text'))
              .decoration({
                type: TextDecorationType.Underline,
                color: $r('app.color.active_text')
              })
              .onClick(() => {
                this.getData();
              })
            Span('。你无需申请校外访问权限。')
          }
          .textAlign(TextAlign.Center)
          .margin({ top: 6, left: 16, right: 16 })
        } else if (this.requestStatus === SearchStatus.LOADING) {
          Row() {
            // LoadingProgress()
            //   .height(30)
            Image($r('app.media.sr_loading_4x'))
              .height(80)
            Text($r('app.string.loading'))
          }
          .margin({ top: 16 })
        } else if (this.requestStatus === SearchStatus.WAITING_FOR_INPUT) {
          Image($r('app.media.sorry'))
            .width(100)
            .margin({ top: 16 })
          Text('获取成功！在上方的文本框键入，再按下键盘上的搜索（Enter）按钮以搜索 qwq\nദ്ദി˶˃ ᵕ ˂ )✧')
            .textAlign(TextAlign.Center)
            .margin({ top: 6, left: 16, right: 16 })
        } else if (this.requestStatus === SearchStatus.NO_RESULT) {
          Image($r('app.media.sorry'))
            .width(100)
            .margin({ top: 16 })
          Text('emm…没有符合条件的搜索结果')
            .textAlign(TextAlign.Center)
            .margin({ top: 6, left: 16, right: 16 })
        } else if (this.requestStatus === SearchStatus.QUERY_SUCCESS) {
          List({ space: 6 }) {
            Repeat<courseFromJW>(this.shownData)
              .each((item: RepeatItem<courseFromJW>) => {
                ListItem() {
                  Row({ space: 10 }) {
                    Text((item.index + 1).toString())
                      .fontSize(30)
                      .fontWeight(FontWeight.Bolder)
                      .textAlign(TextAlign.Center)
                      .width(56)

                    Column() {
                      Text(item.item.course.cn)
                        .fontWeight(FontWeight.Bold)
                        .fontSize(20)
                      Text(item.item.dateTimePlaceText || '无数据')
                        .wordBreak(WordBreak.BREAK_ALL)
                      Text(`${item.item.credits} 学分`)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10, left: 10, right: 10 })
                  .borderRadius(20)
                  .backgroundColor($r('app.color.grid_background'))
                  .onClick(() => this.underConstruction())
                }
                .margin({ top: 4 })
              })

            if (this.resultCount > 200)
              ListItem() {
                Text(`检索到 200+ 个课堂，出于性能考虑，此处只显示 200 个，请考虑使用更精确的关键词`)
              }
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 12, right: 12 })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .contentStartOffset(8)
          .contentEndOffset(12)
        }
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .width('100%')
    }
    .title(this.customTitle(), {
      backgroundBlurStyle: BackgroundImage.blurLevel,
      backgroundColor: BackgroundImage.blurLevel === undefined ? $r('app.color.shaded_background' + String(BackgroundImage.themeColor)) : undefined
    })
    .backButtonIcon($r('app.media.close'))
    .backgroundColor($r('app.color.normal_background')) // BackgroundImage.showImage ? '#00d00721' :
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.getData();
    })
  }

  getData() {
    this.requestStatus = SearchStatus.LOADING;
    const getURL = "https://catalog.ustc.edu.cn/api/teach/lesson/list-for-teach/421";
    const session = rcp.createSession();
    session.get(getURL).then((response) => {
      console.info(`Response code: ${response.statusCode}, Response succeeded: ${response}`);
      if (response.statusCode === 200) {
        this.requestStatus = SearchStatus.WAITING_FOR_INPUT;
        this.obtainedData = response.toJSON() as courseFromJW[];
      }
      else
        this.requestStatus = SearchStatus.GET_DATA_FAILED;
    }).catch((err: BusinessError) => {
      console.error(`Response error code is ${err.code}, error data is ${err.data}`);
      this.requestStatus = SearchStatus.GET_DATA_FAILED;
    });
  }

  searchName(name: string) {
    console.log('debounce')
    try {
      if (name.length === 0) {
        this.resultCount = 0;
        this.requestStatus = SearchStatus.WAITING_FOR_INPUT;
        return;
      }

      if (this.obtainedData) {
        this.requestStatus = SearchStatus.QUERYING;
        this.shownData = [];

        let cnt: number = 0;
        for (let i of this.obtainedData) {
          if (i.course.cn.includes(name)) {
            cnt++;
            if (cnt > 200)
              break;
            this.shownData.push(i);
          }
        }
        this.resultCount = cnt;
        if (cnt === 0) {
          this.requestStatus = SearchStatus.NO_RESULT;
          return;
        }

        this.requestStatus = SearchStatus.QUERY_SUCCESS;
        console.log('debounce' + this.shownData.length.toString());
      } else {
        this.requestStatus = SearchStatus.GET_DATA_FAILED;
      }
    } catch {
      this.requestStatus = SearchStatus.DATA_FORMAT_ERR;
    }
  }

  @Builder customTitle() {
    Row({ space: 5 }) {
      Search({ value: this.className, placeholder: '按课程名搜索' })
        .enabled(this.requestStatus !== SearchStatus.LOADING)
        .layoutWeight(1)
        // .onSubmit((value: string) => {
        //   this.className = value;
        //   this.searchName(value);
        // })
        .onChange((value: string) => {
          this.className = value;
          console.log('debounce debounce');
          if (this.requestStatus !== SearchStatus.GET_DATA_FAILED) {
            const searchCallback = debounce((): void => this.searchName(value), 1000);
            searchCallback();
          }
        })
      Badge({ count: this.resultCount, maxCount: 200,
        style: { badgeColor: /*'#FA2A2D'*/$r('sys.color.ohos_id_color_badge_red') } }) {
        Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
          Image($r('app.media.filter'))
            .height(22)
            .width(22)
        }
        .height(40)
        .width(40)
        .onClick(() => this.underConstruction())
      }
    }
    .padding({ left: 5, right: 7 })
  }

  underConstruction() {
    if (this.requestStatus === SearchStatus.GET_DATA_FAILED)
      this.getUIContext().getPromptAction().showToast({ message: '需要先获取课程数据 qwq' })
    else
      this.getUIContext().getPromptAction().showToast({ message: '此功能正在开发中 qwq' })
  }
}