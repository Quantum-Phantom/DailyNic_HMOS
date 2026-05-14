import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import BackgroundImage, { presetColor } from '../utils/BgImageManager';
import { courseFromJW, debounceSearchCourses, searchCourses, searchOption } from '../utils/Classes/RawDataModifier';


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


@Entry
@Component
struct GetClassByName {

  @State requestStatus: SearchStatus = SearchStatus.LOADING;
  obtainedData: courseFromJW[] = [];
  @State shownData: courseFromJW[] = [];
  advancedFilter: searchOption = {};
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
          Text('获取成功！在上方的文本框键入，再等待一秒以搜索 qwq\nദ്ദി˶˃ ᵕ ˂ )✧')
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
                    Column() {
                      Text((item.index + 1).toString())
                        .fontSize(30)
                        .fontWeight(FontWeight.Bolder)
                        .textAlign(TextAlign.Center)
                      Text(`${item.item.credits} 学分`)
                        .fontSize(12)
                    }
                    .width(56)

                    Column() {
                      Text(item.item.course.cn || '无数据')
                        .fontWeight(FontWeight.Bold)
                        .fontSize(20)
                      Text() {
                        Span('教师  ')
                          .fontWeight(FontWeight.Bold)
                          .fontColor(presetColor[BackgroundImage.themeColor][2])
                        Span(item.item.teacherAssignmentList?.map(item => item.cn).join('，') || '无数据')
                      }
                      .wordBreak(WordBreak.BREAK_ALL)

                      Text() {
                        Span('时间  ')
                          .fontWeight(FontWeight.Bold)
                          .fontColor(presetColor[BackgroundImage.themeColor][2])
                        Span(item.item.dateTimePlacePersonText.cn || '无数据')
                      }
                      .wordBreak(WordBreak.BREAK_ALL)
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
      backgroundColor: BackgroundImage.blurLevel === undefined ? $r('app.color.shaded_background' + String(BackgroundImage.themeColor)) : '#00d00721'
    })
    .backButtonIcon($r('app.media.close'))
    .backgroundBlurStyle(BackgroundImage.blurLevel)
    .backgroundColor(BackgroundImage.showImage ? '#00d00721' : $r('app.color.normal_background'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.getData();
    })
  }

  @Builder settingMenu() {
    Menu() {
      MenuItem({ startIcon: $r('sys.media.ohos_ic_public_text'), content: '区分大小写',
        endIcon: this.advancedFilter.caseSensitive ? $r('app.media.checkmark') : undefined })
        .onClick(() => {
          this.advancedFilter.caseSensitive = !this.advancedFilter.caseSensitive;
          this.shownData = searchCourses(this.obtainedData, this.advancedFilter);
        })
      MenuItem({ startIcon: $r('app.media.cloud_sync'), content: '重新获取' })
        .onClick(() => this.getData())
    }
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

  @Builder customTitle() {
    Row({ space: 5 }) {
      Search({ value: this.advancedFilter.className, placeholder: '按课程名搜索' })
        .enabled(this.requestStatus !== SearchStatus.LOADING)
        .layoutWeight(1)
        // .onSubmit((value: string) => {
        //   this.className = value;
        //   this.searchName(value);
        // })
        .onChange((value: string) => {
          this.advancedFilter.className = value;
          if (value.length === 0)
            debounceSearchCourses([], {}, (empty) => {
              this.resultCount = 0;
              this.shownData = [];
              this.requestStatus = SearchStatus.WAITING_FOR_INPUT;
            })
          else if (this.requestStatus !== SearchStatus.GET_DATA_FAILED) {
            debounceSearchCourses(
              this.obtainedData,
              this.advancedFilter,
              (filteredCourses) => {
                this.shownData = filteredCourses;
                if (filteredCourses.length > 200)
                  this.resultCount = 201;
                else
                  this.resultCount = filteredCourses.length;

                if (this.shownData.length === 0)
                  this.requestStatus = SearchStatus.NO_RESULT;
                else
                  this.requestStatus = SearchStatus.QUERY_SUCCESS;
              }
            );
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

      Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
        Image($r('app.media.setting'))
          .height(22)
          .width(22)
      }
      .height(40)
      .width(40)
      .bindMenu(this.settingMenu())
    }
    .padding({ left: 5, right: 7 })
  }


  @State showFilterDialog: boolean = false;
  targetTeacherName: string = '';
  @Builder filterDialog() {
    Column() {
      Row({ space: 5 }) {
        Text('更多筛选条件')
          .fontWeight(FontWeight.Bold)
          .fontSize(24)
          .layoutWeight(1)
          .margin({ left: 8 })

        Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
          Image($r('app.media.close'))
            .width(24)
            .height(24)
        }
        .height(42)
        .width(42)
        .onClick(() => this.showFilterDialog = false)

        Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
          Image($r('app.media.search'))
            .width(24)
            .height(24)
        }
        .height(42)
        .width(42)
        .onClick(() => {
          this.shownData = searchCourses(this.obtainedData, this.advancedFilter);
          this.showFilterDialog = false;
        })
      }
      Scroll() {
        Column() {
          Row() {
            Text('教师')
            TextInput()
          }
        }
        .padding(16)
      }
    }
  }

  underConstruction() {
    if (this.requestStatus === SearchStatus.GET_DATA_FAILED)
      this.getUIContext().getPromptAction().showToast({ message: '需要先获取课程数据 qwq' })
    else
      this.getUIContext().getPromptAction().showToast({ message: '此功能正在开发中 qwq' })
  }
}