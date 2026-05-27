import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { User } from '../users/user.entity';
import { Archive } from '../archive/archive.entity';

@Entity('directory')
export class Directory {
  @PrimaryGeneratedColumn()
  directory_id!: number;

  @Column()
  directory_name!: string;

  @ManyToOne(() => Directory, directory => directory.children, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'directory_parent' })
  parent!: Directory;

  @OneToMany(() => Directory, directory => directory.parent)
  children!: Directory[];

  @ManyToOne(() => User, user => user.directories, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ name: 'user_id', type: 'int' })
  user_id!: number;

  @OneToMany(() => Archive, archive => archive.directory)
  archives!: Archive[];
}
