import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Directory } from '../directory/directory.entity';

@Entity('archive')
export class Archive {
  @PrimaryGeneratedColumn()
  archive_id!: number;

  @Column()
  archive_na!: string;

  @Column('text')
  symmetric_key!: string;

  @Column('text')
  hash!: string;
  
  @Column('text', { nullable: true })
  private_key?: string | null;

  @Column('text', { nullable: true })
  public_key?: string | null;

  @Column()
  file_path!: string;

  @Column({ type: 'uuid', unique: true, nullable: true })
  share_token?: string | null;

  @Column({ default: false })
  is_public!: boolean;

  // user_id for root-level files (no directory)
  @Column({ type: 'int', nullable: true })
  user_id?: number | null;

  @ManyToOne(() => Directory, directory => directory.archives, { onDelete: 'CASCADE', nullable: true, eager: false })
  @JoinColumn({ name: 'directory_id' })
  directory?: Directory | null;

  @Column({ name: 'directory_id', type: 'int', nullable: true })
  directory_id?: number | null;
}
