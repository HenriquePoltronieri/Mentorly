// Modelo do usuario logado (pode ser coordenacao ou professor)
class UserModel {
  final String id;
  final String nome;
  final String email;
  final String tipo; // "coordenacao" ou "professor"

  UserModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.tipo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      tipo: json['tipo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'tipo': tipo,
    };
  }
}
