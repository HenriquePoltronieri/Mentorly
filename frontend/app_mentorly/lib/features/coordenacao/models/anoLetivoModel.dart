// Ano letivo de uma escola (tabela ano_letivo do backend).
//
// status:
//   planejamento - preparando o ano (aceita turmas e etapas, mas nao e o
//                  contexto do dashboard);
//   atual        - o ano em curso; cada escola tem no maximo um;
//   encerrado    - os dados continuam disponiveis, mas nao nasce turma nem
//                  etapa nova nele.
class AnoLetivoModel {
  static const String planejamento = 'planejamento';
  static const String atual = 'atual';
  static const String encerrado = 'encerrado';

  final int id;
  final int ano;
  final String status;
  final int totalTurmas;
  final int totalEtapas;

  AnoLetivoModel({
    required this.id,
    required this.ano,
    required this.status,
    this.totalTurmas = 0,
    this.totalEtapas = 0,
  });

  factory AnoLetivoModel.fromJson(Map<String, dynamic> json) {
    return AnoLetivoModel(
      id: (json['id'] as num).toInt(),
      ano: (json['ano'] as num).toInt(),
      status: (json['status'] ?? planejamento).toString(),
      totalTurmas: (json['totalTurmas'] as num?)?.toInt() ?? 0,
      totalEtapas: (json['totalEtapas'] as num?)?.toInt() ?? 0,
    );
  }

  bool get ehAtual => status == atual;
  bool get estaEncerrado => status == encerrado;
  bool get estaEmPlanejamento => status == planejamento;

  // Ano sem turma nem etapa pode ser excluido (serve para desfazer um
  // cadastro errado); com dados, o caminho e encerrar.
  bool get temDados => totalTurmas > 0 || totalEtapas > 0;

  String get rotuloStatus {
    switch (status) {
      case atual:
        return 'Atual';
      case encerrado:
        return 'Encerrado';
      default:
        return 'Em planejamento';
    }
  }
}
