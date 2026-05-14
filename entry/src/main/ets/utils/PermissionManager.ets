import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';

const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
const tokenID = bundleManager.getBundleInfoForSelfSync(0x00000001/*GET_BUNDLE_INFO_WITH_APPLICATION*/).appInfo.accessTokenId;

export async function checkPermission(permissionList: Permissions[]): Promise<boolean> {
  const promiseList = permissionList.map(async (permission) => {
    const grantStatus = await atManager.checkAccessToken(tokenID, permission);
    return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  });
  const checkResults = await Promise.all(promiseList);
  return checkResults.every(result => result === true);
}

export async function regainPermission(context: Context, permissionList: Permissions[]): Promise<boolean> {
  if (await checkPermission(permissionList))
    return true;
  atManager.requestPermissionsFromUser(context, ['ohos.permission.APPROXIMATELY_LOCATION'], (err, data) => {
    if (err) {
      console.error(`requestPermissionsFromUser fail, code: ${err.code}, message: ${err.message}`);
      return false;
    } else {
      if (data.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      } else {
        return false;
      }
    }
  })
  return false;
}