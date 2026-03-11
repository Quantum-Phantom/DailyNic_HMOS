/**
 * 启动其他应用，重启或退出自身
 */

import { common, Want } from "@kit.AbilityKit";
import { BusinessError } from '@kit.BasicServicesKit';

export class WantAbility {
  static StartQQ(hostContext: common.UIAbilityContext) {
    hostContext.openLink("mqqapi://card/show_pslcard?src_type=internal&version=1&uin=931920982&card_type=group&source=external&jump_from=webapi",
        { appLinkingOnly: false })
      .catch((error: Error) => {
        hostContext.startAbility({
          action: 'ohos.want.action.viewData',
          entities: ['entity.system.browsable'],
          uri: 'https://qm.qq.com/q/MM3mA0VeW4'
        });
      });
  }

  static restart(hostContext: common.UIAbilityContext) {
    let want: Want = {
      bundleName: 'com.nic.dailynic',
      abilityName: 'EntryAbility'
    };
    try {
      hostContext.getApplicationContext().restartApp(want);
    } catch (error) {
      console.error(`restartApp fail, error: ${JSON.stringify(error)}`);
      if (error.code === 16000064) {
        WantAbility.quit(hostContext);
      }
    }
  }

  static quit(hostContext: common.UIAbilityContext) {
    hostContext.terminateSelf((err) => {
      if (!err) {
        hostContext.getApplicationContext().killAllProcesses().catch((error: Error) => {
          console.error(`Quitting ERROR: [${error.name}] ${error.message}`);
        });
      }
    });
  }

  static openGitHub(hostContext: common.UIAbilityContext) {
    hostContext.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: 'https://github.com/Your-USTC/DailyNic_HMOS/issues'
    }).catch((err: BusinessError) => {
      console.error(`startAbility failed, code is ${err.code}, message is ${err.message}`);
    });
  }
}