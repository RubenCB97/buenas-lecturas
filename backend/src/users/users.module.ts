import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersService } from './users.service';
import { User } from './entities/user.entity';
import { UsersController } from './users.controller';
import { UploadsController } from './uploads.controller';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [UsersService],
  // UploadsController es público (sin JWT) para que las <img> puedan cargarlo
  controllers: [UsersController, UploadsController],
  exports: [UsersService],
})
export class UsersModule {}
