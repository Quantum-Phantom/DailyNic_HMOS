import { GridData, otherGridDataList } from "../constants/GridListDataSources"
import { LINK } from "../constants/Links"

export const webName: ResourceStr[] = [];

@Builder function singleGridItem(pageInfo: NavPathStack, linkName: ResourceStr[], groupIndex: number) {
  Menu() {
    ForEach(linkName, (item: ResourceStr, index: number) => {
      MenuItem({ content: item })
        .onClick(() => {
          const paramData = LINK.get(`${groupIndex}.${index}`);
          webName.push(paramData?.title ?? 'blank');
          pageInfo.pushPath({ name: "Webview", param: paramData });
        })
    })
  }
}

@Builder function singleSection(pageInfo: NavPathStack) {
  Menu() {
    MenuItem({ content: '同时打开过多网页\n会占用大量内存喵', startIcon: $r('app.media.exclamationmark_circle') })
      .contentFont({ size: 14 })
      .hitTestBehavior(HitTestMode.None)
    ForEach(otherGridDataList, (item: GridData, index: number) => {
      MenuItem({
        content: item.groupName,
        builder: singleGridItem(pageInfo, item.gridItemList, index),
        endIcon: $r('sys.media.ohos_ic_public_arrow_right')
      })
    })
  }
}

@Builder function toppingPage(pageInfo: NavPathStack) {
  Menu() {
    ForEach(webName, (item: ResourceStr, index: number) => {
      MenuItem({ content: item })
        .onClick(() => {
          webName.push(webName.splice(index, 1)[0]);
          pageInfo.moveIndexToTop(index);
        })
    })
  }
}

@Builder export function MultiPageMenu(pageInfo: NavPathStack) {
  Menu() {
    MenuItem({ content: '置顶页面', builder: toppingPage(pageInfo), endIcon: $r('sys.media.ohos_ic_public_arrow_right') })
      .enabled(pageInfo.size() > 1)
    MenuItem({ content: '打开新网页', builder: singleSection(pageInfo), endIcon: $r('sys.media.ohos_ic_public_arrow_right') })
  }
}