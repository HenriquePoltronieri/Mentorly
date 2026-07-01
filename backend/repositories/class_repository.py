from database import db
from models.turma import Turma


class ClassRepository:
    def find_all(self):
        return Turma.query.all()

    def find_by_id(self, class_id):
        return Turma.query.get(class_id)

    def find_by_name(self, name):
        return Turma.query.filter_by(name=name).first()

    def create(self, name, description=None):
        turma = Turma(name=name, description=description)
        db.session.add(turma)
        db.session.commit()
        return turma

    def update(self, class_id, name=None, description=None):
        turma = self.find_by_id(class_id)
        if turma is None:
            return None
        if name is not None:
            turma.name = name
        if description is not None:
            turma.description = description
        db.session.commit()
        return turma

    def delete(self, class_id):
        turma = self.find_by_id(class_id)
        if turma is None:
            return False
        db.session.delete(turma)
        db.session.commit()
        return True