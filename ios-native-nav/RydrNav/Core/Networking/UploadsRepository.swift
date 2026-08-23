import UIKit

/// Sube imágenes (avatar, foto de moto, portada de ruta) al backend y
/// devuelve la URL relativa (`/uploads/<archivo>`) que se guarda luego en el
/// registro correspondiente. Espejo de
/// lib/core/api/uploads_repository.dart — llama al mismo endpoint
/// `POST /uploads/image`.
///
/// No reutiliza `APIClient.request` porque ese cliente solo sabe mandar JSON
/// (`JSONSerialization`); una subida de fichero necesita un cuerpo
/// `multipart/form-data` (ver `MultipartFormData`). Sí reutiliza el mismo
/// Keychain para el JWT, igual que hace `APIClient` internamente.
struct UploadsRepository {
    private let keychain = KeychainStore()

    private struct UploadResponse: Decodable { let url: String }

    func uploadImage(_ image: UIImage) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            throw APIError(message: "No se pudo procesar la imagen")
        }

        let form = MultipartFormData()
        let body = form.body(fieldName: "file", fileName: "upload.jpg", mimeType: "image/jpeg", fileData: jpegData)

        guard let url = URL(string: APIConstants.baseURL.absoluteString + APIConstants.uploadImage) else {
            throw APIError(message: "URL de subida inválida")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        if let token = keychain.get(KeychainStore.Keys.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIError(message: "No se pudo subir la imagen")
        }
        return try JSONDecoder().decode(UploadResponse.self, from: data).url
    }
}
