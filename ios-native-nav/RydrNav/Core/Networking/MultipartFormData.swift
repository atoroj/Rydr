import Foundation

/// Construcción mínima de un cuerpo `multipart/form-data` — `URLSession` no
/// trae esto de fábrica y no merece la pena una dependencia solo para subir
/// una imagen. Usado por `UploadsRepository`.
struct MultipartFormData {
    let boundary = "Boundary-\(UUID().uuidString)"

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    func body(fieldName: String, fileName: String, mimeType: String, fileData: Data) -> Data {
        var data = Data()
        data.append(Data("--\(boundary)\r\n".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".utf8))
        data.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        data.append(fileData)
        data.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return data
    }
}
