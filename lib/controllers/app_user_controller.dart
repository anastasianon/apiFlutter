import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:api/model/user.dart';
import 'package:api/utils/app_response.dart';
import 'package:api/utils/app_utils.dart';

class AppUserConttolelr extends ResourceController {
  AppUserConttolelr(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> getProfile(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(id);
      user!.removePropertiesFromBackingMap(['refreshToken', 'accessToken']);

      return AppResponse.ok(
          message: 'Успешное получение профиля', body: user.backing.contents);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения профиля');
    }
  }

  @Operation.post()
  Future<Response> updateProfile(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() User user,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final fUser = await managedContext.fetchObjectWithID<User>(id);
      final qUpdateUser = Query<User>(managedContext)
        ..where((element) => element.id)
            .equalTo(id)
        ..values.userName = user.userName ?? fUser!.userName
        ..values.email = user.email ?? fUser!.email;
      await qUpdateUser.updateOne();
      final findUser = await managedContext.fetchObjectWithID<User>(id);
      findUser!.removePropertiesFromBackingMap(['refreshToken', 'accessToken']);

      return AppResponse.ok(
        message: 'Успешное обновление данных',
        body: findUser.backing.contents,
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }

  @Operation.put()
  Future<Response> updatePassword(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query("newPassword") String newPassword,
    @Bind.query("oldPassword") String oldPassword,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final qFindUser = Query<User>(managedContext)
        ..where((element) => element.id).equalTo(id)
        ..returningProperties(
          (element) => [
            element.salt,
            element.hashPassword,
          ],
        );

      final fUser = await qFindUser.fetchOne();

      final oldHashPassword =
          generatePasswordHash(oldPassword, fUser!.salt ?? "");

      if (oldHashPassword != fUser.hashPassword) {
        return AppResponse.badrequest(
          message: 'Неверный старый пароль',
        );
      }

      final newHashPassword =
          generatePasswordHash(newPassword, fUser.salt ?? "");

      final qUpdateUser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..values.hashPassword = newHashPassword;

      await qUpdateUser.fetchOne();

      return AppResponse.ok(body: 'Пароль успешно обновлен');
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления пароля');
    }
  }
}
