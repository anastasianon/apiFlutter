import 'dart:ffi';
import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:api/model/user.dart';
import 'package:api/utils/app_response.dart';
import 'package:api/utils/app_utils.dart';
import 'package:api/model/finsns.dart';

class AppNoteController extends ResourceController {
  AppNoteController(this.managedContext);

  final ManagedContext managedContext;

//получение одного отчета по его номеру
  @Operation.get("number")
  Future<Response> getNote(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("number") int number,
      {@Bind.query("recovery") bool? recovery}) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);

      final deletedNoteQuery = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..where((note) => note.user!.id).equalTo(currentUserId)
        ..where((note) => note.status).equalTo("true");

        // fetchOne-

      final deletedNote = await deletedNoteQuery.fetchOne();

      String message = "Успешное получение финансового отчета";

      if (deletedNote != null && recovery != null && recovery) {
        deletedNoteQuery.values.status = "false";
        deletedNoteQuery.update();
        message = "Успешное восстановление финансового отчета";
      }

      final noteQuery = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..where((note) => note.user!.id).equalTo(currentUserId)
        ..where((note) => note.status).equalTo("false");
      final note = await noteQuery.fetchOne();
      if (note == null) {
        return AppResponse.ok(message: "Финансовый отчет не найден");
      }
      note.removePropertiesFromBackingMap(["user", "id", "deleted"]);
      return AppResponse.ok(body: note.backing.contents, message: message);
    } catch (e) {
      return AppResponse.serverError(e,
          message: 'Ошибка получения финансового отчета');
    }
  }

  @Operation.put("number")
  Future<Response> updateNote(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("number") int number,
      @Bind.body() Note note) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);
      final noteQuery = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..where((note) => note.user!.id).equalTo(currentUserId)
        ..where((note) => note.status).equalTo("false");
      final noteDB = await noteQuery.fetchOne();
      if (noteDB == null) {
        return AppResponse.ok(message: "Финансовый отчет не найден");
      }
      final qUpdateNote = Query<Note>(managedContext)
        ..where((note) => note.id).equalTo(noteDB.id)
        ..values.category = note.category
        ..values.name = note.name
        ..values.text = note.text
        ..values.amount = note.amount;
      await qUpdateNote.update();
      return AppResponse.ok(
          body: note.backing.contents,
          message: "Успешное обновление финансового отчета");
    } catch (e) {
      return AppResponse.serverError(e,
          message: 'Ошибка получения финансового отчета');
    }
  }
  //п
  @Operation.get()
  Future<Response> getNotes(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      {@Bind.query("search") String? search,
      @Bind.query("limit") int? limit,
      @Bind.query("offset") int? offset,
      @Bind.query("filter") String? filter}) async {
    try {
      final id = AppUtils.getIdFromHeader(header);

      Query<Note>? notesQuery;

      if (search != null && search != "") {
        notesQuery = Query<Note>(managedContext)
          ..where((note) => note.name).contains(search)
          ..where((note) => note.user!.id).equalTo(id);
      } else {
        notesQuery = Query<Note>(managedContext)
          ..where((note) => note.user!.id).equalTo(id);
      }

      switch (filter) {
        case "deleted":
          notesQuery.where((note) => note.status).equalTo("true");
          break;
        case "all":
          break;
        default:
          notesQuery.where((note) => note.status).equalTo("false");
      }
//пагинация fetchLimit-позволяет установить лимит элементов
      if (limit != null && limit > 0) {
        notesQuery.fetchLimit = limit;
      }
      if (offset != null && offset > 0) {
        notesQuery.offset = offset;
      }

      final notes = await notesQuery.fetch();

      List notesJson = List.empty(growable: true);

      for (final note in notes) {
        note.removePropertiesFromBackingMap(["user", "id", "deleted"]);
        notesJson.add(note.backing.contents);
      }

      if (notesJson.isEmpty) {
        return AppResponse.ok(message: "Финансовые отчеты не найдены");
      }

      return AppResponse.ok(
          message: 'Успешное получение финансового отчета', body: notesJson);
    } catch (e) {
      return AppResponse.serverError(e,
          message: 'Ошибка получения финансового отчета');
    }
  }

  @Operation.delete("number")
  Future<Response> deleteNote(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("number") int number) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);
      final noteQuery = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..where((note) => note.user!.id).equalTo(currentUserId)
        ..where((note) => note.status).equalTo("false");
      final note = await noteQuery.fetchOne();
      if (note == null) {
        return AppResponse.ok(message: "Финансовый отчет не найден");
      }
      final qLogicDeleteNote = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..values.status = "true";
      await qLogicDeleteNote.update();
      return AppResponse.ok(message: 'Успешное удаление финансового отчета');
    } catch (e) {
      return AppResponse.serverError(e,
          message: 'Ошибка удаления финансового отчета');
    }
  }

  @Operation.post()
  Future<Response> createNote(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Note note) async {
    try {
      late final int noteId;

      final id = AppUtils.getIdFromHeader(header);

      final notesQuery = Query<Note>(managedContext)
        ..where((note) => note.user!.id).equalTo(id);

      final notes = await notesQuery.fetch();

      final noteNumber = notes.length;

      final fUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id);

      final user = await fUser.fetchOne();

      await managedContext.transaction((transaction) async {
        final qCreateNote = Query<Note>(transaction)
          ..values.number = noteNumber + 1
          ..values.name = note.name
          ..values.text = note.text
          ..values.category = note.category
          ..values.dateTimeOperation = DateTime.now().toString()
          ..values.amount = note.amount
          ..values.user = user
          ..values.status = "false";

        final createdNote = await qCreateNote.insert();

        noteId = createdNote.id!;
      });

      final noteData = await managedContext.fetchObjectWithID<Note>(noteId);

      noteData!.removePropertiesFromBackingMap(["user", "id", "deleted"]);
      return AppResponse.ok(
        body: noteData.backing.contents,
        message: 'Успешное создание финансового отчета',
      );
    } catch (e) {
      return AppResponse.serverError(e,
          message: 'Ошибка создания финансового отчета');
    }
  }
}
